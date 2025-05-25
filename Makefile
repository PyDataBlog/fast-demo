# Makefile for Fast Demo API project

# Variables
K8S_CLUSTER_NAME ?= mycluster
DOCKER_IMAGE_NAME ?= fast-demo
DOCKER_IMAGE_TAG ?= latest
K8S_NAMESPACE ?= demo
K8S_INGRESS_IP ?=
K8S_MANIFEST_TEMPLATE := k8s-fast-demo.yaml.template
K8S_MANIFEST := k8s-fast-demo.yaml

# Phony targets
.PHONY: help all-k8s k3d-cluster-create install-nginx docker-build k3d-image-import k8s-prepare-manifest k8s-deploy k8s-access k8s-delete k3d-cluster-delete clean-k8s docker-run-local docker-access-local

# Default target
default: help

help:
	@echo "Makefile for Fast Demo API project"
	@echo ""
	@echo "Usage: make [target] [VARIABLE=value]"
	@echo ""
	@echo "Variables (can be overridden on the command line):"
	@echo "  K8S_CLUSTER_NAME   Cluster name for k3d (default: $(K8S_CLUSTER_NAME))"
	@echo "  DOCKER_IMAGE_NAME  Docker image name (default: $(DOCKER_IMAGE_NAME))"
	@echo "  DOCKER_IMAGE_TAG   Docker image tag (default: $(DOCKER_IMAGE_TAG))"
	@echo "  K8S_NAMESPACE      Kubernetes namespace for deployment (default: $(K8S_NAMESPACE))"
	@echo "  K8S_INGRESS_IP     Ingress IP for Kubernetes. Must be provided for k8s-deploy."
	@echo "                     Example: make k8s-deploy K8S_INGRESS_IP=192.168.86.160"
	@echo ""
	@echo "Kubernetes (k3d) Targets:"
	@echo "  k3d-cluster-create   Creates a k3d cluster."
	@echo "  install-nginx        Installs Nginx Ingress Controller via Helm."
	@echo "  docker-build         Builds the Docker image '$(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_TAG)'."
	@echo "  k3d-image-import     Imports the Docker image into the k3d cluster (depends on docker-build)."
	@echo "  k8s-deploy           Prepares manifest & deploys the app to K8s. Requires K8S_INGRESS_IP."
	@echo "  all-k8s              Runs: docker-build, k3d-image-import, k8s-deploy, k8s-access. Requires K8S_INGRESS_IP."
	@echo "                       (Assumes cluster and Nginx ingress are already set up)."
	@echo "  k8s-access           Shows how to access the application on k3d (requires K8S_INGRESS_IP)."
	@echo "  k8s-delete           Deletes the Kubernetes deployment, service, and namespace."
	@echo "  k3d-cluster-delete   Deletes the k3d cluster '$(K8S_CLUSTER_NAME)'."
	@echo "  clean-k8s            Runs k8s-delete and k3d-cluster-delete, and removes generated manifest."
	@echo ""
	@echo "Local Docker Targets:"
	@echo "  docker-run-local     Builds (if needed) and runs the app using Docker locally on port 8000."
	@echo "  docker-access-local  Shows how to access the app running locally in Docker."

# Kubernetes (k3d) Targets
k3d-cluster-create:
	@echo "Creating k3d cluster '$(K8S_CLUSTER_NAME)'..."
	k3d cluster create $(K8S_CLUSTER_NAME) --api-port 6443 --k3s-arg="--disable=traefik@server:0" -p "80:80@loadbalancer" -p "443:443@loadbalancer" --servers 1 --agents 3

install-nginx:
	@echo "Installing Nginx Ingress Controller..."
	helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
	helm repo update
	helm install ingress-nginx ingress-nginx/ingress-nginx \
	  --namespace ingress-nginx \
	  --create-namespace \
	  --wait

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
	@echo "Preparing Kubernetes manifest '$(K8S_MANIFEST)' with IP $(K8S_INGRESS_IP)..."
	sed 's/{{K8S_INGRESS_IP}}/$(K8S_INGRESS_IP)/g' $(K8S_MANIFEST_TEMPLATE) > $(K8S_MANIFEST)

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
	@echo "Access the application on k3d (using IP: $(K8S_INGRESS_IP)):"
	@echo "  Main API Root: http://$(K8S_INGRESS_IP).nip.io/api/"
	@echo "  Main API Items (POST): http://$(K8S_INGRESS_IP).nip.io/api/items/"
	@echo "  Sub API v21 Index: http://$(K8S_INGRESS_IP).nip.io/api/v21/"
	@echo "  Sub API v21 Sub-route: http://$(K8S_INGRESS_IP).nip.io/api/v21/sub"
	@echo "Example using curl:"
	@echo "  curl http://$(K8S_INGRESS_IP).nip.io/api/"

k8s-delete:
	@echo "Deleting Kubernetes resources from manifest '$(K8S_MANIFEST)' in namespace '$(K8S_NAMESPACE)'..."
	kubectl delete -f $(K8S_MANIFEST) --ignore-not-found=true
	@# Namespace itself is deleted if it was defined in the manifest and no other resources exist.
	@# If namespace was created separately or contains other items, it might need explicit deletion.
	@# For this setup, the manifest includes the namespace, so 'kubectl delete -f' should handle it.
	@# If issues, uncomment: kubectl delete namespace $(K8S_NAMESPACE) --ignore-not-found=true

k3d-cluster-delete:
	@echo "Deleting k3d cluster '$(K8S_CLUSTER_NAME)'..."
	k3d cluster delete $(K8S_CLUSTER_NAME)

clean-k8s: k8s-delete k3d-cluster-delete
	@echo "Cleaning up generated manifest file '$(K8S_MANIFEST)'..."
	rm -f $(K8S_MANIFEST)

# Local Docker Targets
docker-run-local: docker-build
	@echo "Running Docker container '$(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_TAG)' locally on port 8000..."
	docker run -p 8000:8000 $(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_TAG)

docker-access-local:
	@echo "Access the application (local Docker):"
	@echo "  Main API Root: http://localhost:8000/api/docs"
	@echo "  Main API Items (POST): http://localhost:8000/api/items/"
	@echo "  Sub API v21 Index: http://localhost:8000/api/v21/docs"
	@echo "  Sub API v21 Sub-route: http://localhost:8000/api/v21/sub"
	@echo "Example using curl:"
	@echo "  curl http://localhost:8000/api/"
