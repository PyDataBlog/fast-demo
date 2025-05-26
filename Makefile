# Makefile for Fast Demo API project

# Variables
K8S_CLUSTER_NAME ?= mycluster
DOCKER_IMAGE_NAME ?= fast-demo
K8S_NAMESPACE ?= demo
K8S_INGRESS_IP ?=
API_VERSION ?= v21
DOCKER_IMAGE_TAG ?= $(API_VERSION)
K8S_MANIFEST_TEMPLATE := k8s-fast-demo.yaml.template
K8S_MANIFEST := k8s-fast-demo.yaml

NGF_CRD_REF_VERSION ?= v1.6.2
NGF_HELM_REPO_URL ?= oci://ghcr.io/nginx/charts/nginx-gateway-fabric
NGF_CHART_NAME ?= nginx-gateway-fabric
NGF_NAMESPACE ?= nginx-gateway

.PHONY: default help all-k8s k3d-cluster-create k8s-install-gateway-crds install-nginx-gateway docker-build k3d-image-import k8s-prepare-manifest k8s-deploy k8s-access k8s-delete k3d-cluster-delete clean-k8s docker-run-local docker-access-local

default: help

help:
	@echo "Makefile for Fast Demo API project (using Nginx Gateway API)"
	@echo ""
	@echo "Usage: make [target] [VARIABLE=value]"
	@echo ""
	@echo "Variables (can be overridden on the command line):"
	@echo "  K8S_CLUSTER_NAME      Cluster name for k3d (default: $(K8S_CLUSTER_NAME))"
	@echo "  DOCKER_IMAGE_NAME     Docker image name (default: $(DOCKER_IMAGE_NAME))"
	@echo "  DOCKER_IMAGE_TAG      Docker image tag (default: $(DOCKER_IMAGE_TAG))"
	@echo "  K8S_NAMESPACE         Kubernetes namespace for app deployment (default: $(K8S_NAMESPACE))"
	@echo "  K8S_INGRESS_IP        IP for Kubernetes Gateway. Must be provided for k8s-deploy."
	@echo "                        Example: make k8s-deploy K8S_INGRESS_IP=192.168.86.160"
	@echo "  API_VERSION           Sub-API path prefix (default: $(API_VERSION))"
	@echo "  NGF_CRD_REF_VERSION   Ref (tag/branch) for Nginx Gateway Fabric CRDs (default: $(NGF_CRD_REF_VERSION))"
	@echo "  NGF_NAMESPACE         Namespace for Nginx Gateway Fabric (default: $(NGF_NAMESPACE))"
	@echo ""
	@echo "Kubernetes (k3d) Targets:"
	@echo "  k3d-cluster-create      Creates a k3d cluster."
	@echo "  k8s-install-gateway-crds Installs Kubernetes Gateway API CRDs using kustomize from NGF repo."
	@echo "  install-nginx-gateway   Installs Nginx Gateway Fabric via Helm (depends on CRDs)."
	@echo "  docker-build            Builds the Docker image '$(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_TAG)'."
	@echo "  k3d-image-import        Imports the Docker image into the k3d cluster (depends on docker-build)."
	@echo "  k8s-deploy              Prepares manifest & deploys the app to K8s. Requires K8S_INGRESS_IP."
	@echo "  all-k8s                 Runs: docker-build, k3d-image-import, k8s-deploy, k8s-access. Requires K8S_INGRESS_IP."
	@echo "                          (Assumes cluster, Gateway CRDs and Nginx Gateway Fabric are already set up)."
	@echo "  k8s-access              Shows how to access the application on k3d (requires K8S_INGRESS_IP)."
	@echo "  k8s-delete              Deletes the Kubernetes deployment, service, gateway resources, and namespace."
	@echo "  k3d-cluster-delete      Deletes the k3d cluster '$(K8S_CLUSTER_NAME)'."
	@echo "  clean-k8s               Runs k8s-delete and k3d-cluster-delete, and removes generated manifest."
	@echo ""
	@echo "Local Docker Targets:"
	@echo "  docker-run-local        Builds (if needed) and runs the app using Docker locally on port 8000."
	@echo "  docker-access-local     Shows how to access the app running locally in Docker."

k3d-cluster-create:
	@echo "Creating k3d cluster '$(K8S_CLUSTER_NAME)'..."
	k3d cluster create $(K8S_CLUSTER_NAME) --api-port 6443 --k3s-arg="--disable=traefik@server:0" -p "80:80@loadbalancer" --servers 1 --agents 3

k8s-install-gateway-crds:
	@echo "Installing Kubernetes Gateway API CRDs from Nginx Gateway Fabric repo (ref: $(NGF_CRD_REF_VERSION))..."
	kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=$(NGF_CRD_REF_VERSION)" | kubectl apply -f -

install-nginx-gateway: k8s-install-gateway-crds
	@echo "Installing Nginx Gateway Fabric in namespace '$(NGF_NAMESPACE)'..."
	helm install $(NGF_CHART_NAME) $(NGF_HELM_REPO_URL) \
	  --namespace $(NGF_NAMESPACE) \
	  --create-namespace \
	  --wait
	@echo "Nginx Gateway Fabric installed."
	@echo "Ensure your Gateway resource in '$(K8S_MANIFEST)' uses 'gatewayClassName: nginx'."

docker-build:
	@echo "Building Docker image '$(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_TAG)'..."
	docker build -t $(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_TAG) .

k3d-image-import: docker-build
	@echo "Importing Docker image '$(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_TAG)' into k3d cluster '$(K8S_CLUSTER_NAME)'..."
	k3d image import $(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_TAG) --cluster $(K8S_CLUSTER_NAME)

k8s-prepare-manifest:
	@if [ -z "$(K8S_INGRESS_IP)" ]; then \
		echo "Error: K8S_INGRESS_IP is not set."; \
		echo "Please provide it, e.g., make k8s-deploy K8S_INGRESS_IP=1.2.3.4"; \
		exit 1; \
	fi
	@echo "Preparing Kubernetes manifest '$(K8S_MANIFEST)' with IP $(K8S_INGRESS_IP) and API Version Path $(API_VERSION)..."
	sed -e 's~{{K8S_INGRESS_IP}}~$(K8S_INGRESS_IP)~g' \
	    -e 's~{{API_VERSION}}~$(API_VERSION)~g' \
	    $(K8S_MANIFEST_TEMPLATE) > $(K8S_MANIFEST)

k8s-deploy: k8s-prepare-manifest
	@echo "Deploying application to Kubernetes namespace '$(K8S_NAMESPACE)'..."
	kubectl apply -f $(K8S_MANIFEST)
	@echo "Monitor pod status with: kubectl get pods -n $(K8S_NAMESPACE) -w"

all-k8s: k3d-image-import k8s-deploy k8s-access

k8s-access:
	@if [ -z "$(K8S_INGRESS_IP)" ]; then \
		echo "K8S_INGRESS_IP is not set. Cannot show access URLs."; \
		echo "Run 'make k8s-deploy K8S_INGRESS_IP=your.ip.here' or set K8S_INGRESS_IP when calling this target."; \
		exit 1; \
	fi
	@echo "Access the application on k3d (using IP: $(K8S_INGRESS_IP), API Version Path: $(API_VERSION)):"
	@echo "  Main API Root: http://$(K8S_INGRESS_IP).nip.io/api/"
	@echo "  Main API Items (POST): http://$(K8S_INGRESS_IP).nip.io/api/items/"
	@echo "  Sub API $(API_VERSION) Index: http://$(K8S_INGRESS_IP).nip.io/api/$(API_VERSION)/"
	@echo "  Sub API $(API_VERSION) Sub-route: http://$(K8S_INGRESS_IP).nip.io/api/$(API_VERSION)/sub"
	@echo "Example using curl:"
	@echo "  curl http://$(K8S_INGRESS_IP).nip.io/api/$(API_VERSION)/"

k8s-delete:
	@echo "Deleting Kubernetes resources from manifest '$(K8S_MANIFEST)' in namespace '$(K8S_NAMESPACE)'..."
	kubectl delete -f $(K8S_MANIFEST) --ignore-not-found=true

k3d-cluster-delete:
	@echo "Deleting k3d cluster '$(K8S_CLUSTER_NAME)'..."
	k3d cluster delete $(K8S_CLUSTER_NAME)

clean-k8s: k8s-delete k3d-cluster-delete
	@echo "Cleaning up generated manifest file '$(K8S_MANIFEST)'..."
	rm -f $(K8S_MANIFEST)

docker-run-local: docker-build
	@echo "Running Docker container '$(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_TAG)' locally on port 8000 with API Version Path $(API_VERSION)..."
	docker run -d --rm -p 8000:8000 -e API_VERSION=$(API_VERSION) --name $(DOCKER_IMAGE_NAME)-local $(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_TAG)
	@echo "Container started. To stop: docker stop $(DOCKER_IMAGE_NAME)-local"

docker-access-local:
	@echo "Access the application (local Docker, API Version Path: $(API_VERSION)):"
	@echo "  Main API Docs: http://localhost:8000/api/docs"
	@echo "  Main API Items (POST): http://localhost:8000/api/items/"
	@echo "  Sub API $(API_VERSION) Docs: http://localhost:8000/api/$(API_VERSION)/docs"
	@echo "  Sub API $(API_VERSION) Index: http://localhost:8000/api/$(API_VERSION)/"
	@echo "  Sub API $(API_VERSION) Sub-route: http://localhost:8000/api/$(API_VERSION)/sub"
	@echo "Example using curl:"
	@echo "  curl http://localhost:8000/api/$(API_VERSION)/"
