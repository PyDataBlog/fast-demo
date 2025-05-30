# Makefile for Fast Demo API project (using Operator)

# Variables
K8S_CLUSTER_NAME ?= mycluster
DOCKER_IMAGE_NAME ?= fast-demo
API_VERSION ?= v21 # Used for App image tag and should match CR spec
DOCKER_IMAGE_TAG ?= $(API_VERSION)
APP_NAMESPACE ?= demo # Namespace for the application deployment (must match CR spec.namespace)

# K8S_INGRESS_IP must be provided for k8s-access and should match the CR spec.ingressIP
K8S_INGRESS_IP ?=

NGF_CRD_REF_VERSION ?= v1.6.2
NGF_HELM_REPO_URL ?= oci://ghcr.io/nginx/charts/nginx-gateway-fabric
NGF_CHART_NAME ?= nginx-gateway-fabric
NGF_NAMESPACE ?= nginx-gateway

OPERATOR_PROJECT_DIR := FastAPIOperator
OPERATOR_IMG_NAME ?= fastapioperator-controller
OPERATOR_IMG_TAG ?= v0.0.1 # Should match the version you build the operator with
OPERATOR_FULL_IMG := $(OPERATOR_IMG_NAME):$(OPERATOR_IMG_TAG)
OPERATOR_NAMESPACE ?= fastapioperator-system # Default namespace for operator-sdk controllers
CR_SAMPLE_YAML := $(OPERATOR_PROJECT_DIR)/config/samples/dev_v1alpha1_fastapimanaged.yaml
CR_NAME ?= fastapimanaged-sample # Name of the CR instance in the sample YAML

.PHONY: default help all-k8s k3d-cluster-create k8s-install-gateway-crds install-nginx-gateway \
	docker-build k3d-image-import \
	operator-build operator-k3d-image-import operator-install-crds operator-deploy operator-undeploy operator-uninstall-crds \
	app-cr-deploy app-cr-delete \
	k8s-access k8s-delete-all-app-resources k3d-cluster-delete clean-k8s \
	docker-run-local docker-access-local

default: help

help:
	@echo "Makefile for Fast Demo API project (using Nginx Gateway API and FastAPIManaged Operator)"
	@echo ""
	@echo "Usage: make [target] [VARIABLE=value]"
	@echo ""
	@echo "Variables (can be overridden on the command line):"
	@echo "  K8S_CLUSTER_NAME      Cluster name for k3d (default: $(K8S_CLUSTER_NAME))"
	@echo "  DOCKER_IMAGE_NAME     Application Docker image name (default: $(DOCKER_IMAGE_NAME))"
	@echo "  API_VERSION           Application version, used for app image tag and in CR (default: $(API_VERSION))"
	@echo "  DOCKER_IMAGE_TAG      Application Docker image tag (default: $(DOCKER_IMAGE_TAG))"
	@echo "  APP_NAMESPACE         Kubernetes namespace for app deployment via CR (default: $(APP_NAMESPACE))"
	@echo "  K8S_INGRESS_IP        IP for Kubernetes Gateway. Must be set in CR. Provide here for 'k8s-access'."
	@echo "                        Example: make k8s-access K8S_INGRESS_IP=192.168.86.160"
	@echo "  NGF_CRD_REF_VERSION   Ref for Nginx Gateway Fabric CRDs (default: $(NGF_CRD_REF_VERSION))"
	@echo "  NGF_NAMESPACE         Namespace for Nginx Gateway Fabric (default: $(NGF_NAMESPACE))"
	@echo "  OPERATOR_PROJECT_DIR  Directory of the operator project (default: $(OPERATOR_PROJECT_DIR))"
	@echo "  OPERATOR_IMG_NAME     Operator Docker image name (default: $(OPERATOR_IMG_NAME))"
	@echo "  OPERATOR_IMG_TAG      Operator Docker image tag (default: $(OPERATOR_IMG_TAG))"
	@echo "  OPERATOR_NAMESPACE    Namespace where the operator is deployed (default: $(OPERATOR_NAMESPACE))"
	@echo "  CR_SAMPLE_YAML        Path to the FastAPIManaged CR sample (default: $(CR_SAMPLE_YAML))"
	@echo "  CR_NAME               Name of the FastAPIManaged CR instance (default: $(CR_NAME))"
	@echo ""
	@echo "Kubernetes (k3d) Targets:"
	@echo "  k3d-cluster-create      Creates a k3d cluster."
	@echo "  k8s-install-gateway-crds Installs Kubernetes Gateway API CRDs."
	@echo "  install-nginx-gateway   Installs Nginx Gateway Fabric via Helm."
	@echo "  docker-build            Builds the application Docker image '$(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_TAG)'."
	@echo "  k3d-image-import        Imports the application Docker image into k3d."
	@echo "  operator-build          Builds the operator Docker image '$(OPERATOR_FULL_IMG)'."
	@echo "  operator-k3d-image-import Imports the operator Docker image into k3d."
	@echo "  operator-install-crds   Installs CRDs required by the operator."
	@echo "  operator-deploy         Deploys the operator controller to '$(OPERATOR_NAMESPACE)'."
	@echo "  app-cr-deploy           Deploys the FastAPIManaged Custom Resource to '$(APP_NAMESPACE)'."
	@echo "                          (Ensure '$(CR_SAMPLE_YAML)' is configured correctly)."
	@echo "  all-k8s                 Runs: docker-build, k3d-image-import, operator-build, operator-k3d-image-import,"
	@echo "                          operator-install-crds, operator-deploy, app-cr-deploy, k8s-access."
	@echo "                          (Assumes cluster, Gateway CRDs and Nginx Gateway Fabric are set up)."
	@echo "                          Requires K8S_INGRESS_IP for the access step."
	@echo "  k8s-access              Shows how to access the application on k3d."
	@echo "  app-cr-delete           Deletes the FastAPIManaged CR from '$(APP_NAMESPACE)'."
	@echo "  operator-undeploy       Undeploys the operator controller from '$(OPERATOR_NAMESPACE)'."
	@echo "  operator-uninstall-crds Uninstalls CRDs for the operator."
	@echo "  k8s-delete-all-app-resources Deletes the application's FastAPIManaged CR."
	@echo "  k3d-cluster-delete      Deletes the k3d cluster '$(K8S_CLUSTER_NAME)'."
	@echo "  clean-k8s               Runs: app-cr-delete, operator-undeploy, (optionally operator-uninstall-crds), k3d-cluster-delete."
	@echo ""
	@echo "Local Docker Targets (for application):"
	@echo "  docker-run-local        Builds (if needed) and runs the app using Docker locally."
	@echo "  docker-access-local     Shows how to access the app running locally in Docker."

# --- Cluster & Gateway Setup ---
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

# --- Application Image ---
docker-build:
	@echo "Building application Docker image '$(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_TAG)'..."
	docker build -t $(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_TAG) .

k3d-image-import: docker-build
	@echo "Importing application Docker image '$(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_TAG)' into k3d cluster '$(K8S_CLUSTER_NAME)'..."
	k3d image import $(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_TAG) --cluster $(K8S_CLUSTER_NAME)

# --- Operator Lifecycle ---
operator-build:
	@echo "Building operator Docker image '$(OPERATOR_FULL_IMG)' from $(OPERATOR_PROJECT_DIR)..."
	cd $(OPERATOR_PROJECT_DIR) && $(MAKE) docker-build IMG=$(OPERATOR_FULL_IMG)

operator-k3d-image-import: operator-build
	@echo "Importing operator Docker image '$(OPERATOR_FULL_IMG)' into k3d cluster '$(K8S_CLUSTER_NAME)'..."
	k3d image import $(OPERATOR_FULL_IMG) --cluster $(K8S_CLUSTER_NAME)

operator-install-crds:
	@echo "Installing operator CRDs from $(OPERATOR_PROJECT_DIR)..."
	cd $(OPERATOR_PROJECT_DIR) && $(MAKE) install

operator-deploy: operator-install-crds
	@echo "Deploying operator '$(OPERATOR_FULL_IMG)' from $(OPERATOR_PROJECT_DIR) to namespace '$(OPERATOR_NAMESPACE)'..."
	cd $(OPERATOR_PROJECT_DIR) && $(MAKE) deploy IMG=$(OPERATOR_FULL_IMG)
	@echo "Monitor operator status with: kubectl get pods -n $(OPERATOR_NAMESPACE) -w"

operator-undeploy:
	@echo "Undeploying operator from $(OPERATOR_PROJECT_DIR) and namespace '$(OPERATOR_NAMESPACE)'..."
	cd $(OPERATOR_PROJECT_DIR) && $(MAKE) undeploy IMG=$(OPERATOR_FULL_IMG) # IMG might be needed by kustomize edits in operator's undeploy

operator-uninstall-crds:
	@echo "Uninstalling operator CRDs from $(OPERATOR_PROJECT_DIR)..."
	cd $(OPERATOR_PROJECT_DIR) && $(MAKE) uninstall

# --- Application CR Lifecycle ---
app-cr-deploy:
	@echo "Deploying FastAPIManaged CR '$(CR_NAME)' from '$(CR_SAMPLE_YAML)' to namespace '$(APP_NAMESPACE)'..."
	@echo "Ensure '$(CR_SAMPLE_YAML)' is configured with your desired spec (namespace, image name, apiVersion, ingressIP, etc.)."
	kubectl apply -f $(CR_SAMPLE_YAML) -n $(APP_NAMESPACE)
	@echo "Monitor application status with: kubectl get fastapimanaged $(CR_NAME) -n $(APP_NAMESPACE) -o yaml"
	@echo "And: kubectl get pods,svc,gateway,httproute -n $(APP_NAMESPACE)"

app-cr-delete:
	@echo "Deleting FastAPIManaged CR '$(CR_NAME)' using file '$(CR_SAMPLE_YAML)' from namespace '$(APP_NAMESPACE)'..."
	kubectl delete -f $(CR_SAMPLE_YAML) -n $(APP_NAMESPACE) --ignore-not-found=true

# --- Composite Targets ---
all-k8s: docker-build k3d-image-import operator-build operator-k3d-image-import operator-deploy app-cr-deploy k8s-access

k8s-delete-all-app-resources: app-cr-delete

k8s-access:
	@if [ -z "$(K8S_INGRESS_IP)" ]; then \
		echo "K8S_INGRESS_IP is not set. Cannot show access URLs."; \
		echo "Please provide it, e.g., make k8s-access K8S_INGRESS_IP=your.ip.here API_VERSION=your.version"; \
		echo "This IP and API_VERSION should match what is configured in your FastAPIManaged CR."; \
		exit 1; \
	fi
	@echo "Access the application on k3d (using IP: $(K8S_INGRESS_IP), API Version Path: $(API_VERSION)):"
	@echo "  (Ensure these values match your deployed FastAPIManaged CR spec)"
	@echo "  Main API Root: http://$(K8S_INGRESS_IP).nip.io/api/"
	@echo "  Main API Items (POST): http://$(K8S_INGRESS_IP).nip.io/api/items/"
	@echo "  Sub API $(API_VERSION) Index: http://$(K8S_INGRESS_IP).nip.io/api/$(API_VERSION)/"
	@echo "  Sub API $(API_VERSION) Sub-route: http://$(K8S_INGRESS_IP).nip.io/api/$(API_VERSION)/sub"
	@echo "Example using curl:"
	@echo "  curl http://$(K8S_INGRESS_IP).nip.io/api/$(API_VERSION)/"

clean-k8s: app-cr-delete operator-undeploy k3d-cluster-delete
	@echo "Consider running 'make operator-uninstall-crds' separately if you want to remove operator CRDs."

# --- Local Docker for Application ---
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

k3d-cluster-delete:
	@echo "Deleting k3d cluster '$(K8S_CLUSTER_NAME)'..."
	k3d cluster delete $(K8S_CLUSTER_NAME)

