# Fast Demo API (with Nginx Gateway API)

This project is a FastAPI application. This guide explains how to run it using Kubernetes (with k3d and Nginx Gateway API) or Docker directly.

## Using the Makefile

A `Makefile` is provided to simplify common tasks. Run `make help` to see available targets and options.
You will need to have `make` installed on your system.

Key variables for the Makefile:

- `K8S_INGRESS_IP`: Your desired IP for the Kubernetes Gateway (e.g., `192.168.86.160`). This **must** be provided for Kubernetes deployment targets. Example: `make k8s-deploy K8S_INGRESS_IP=your.ip.address`.
- `API_VERSION`: The path prefix for the sub-API (default: `v21`). Example: `make k8s-deploy API_VERSION=v22`.
- `K8S_CLUSTER_NAME`: Name for the k3d cluster (default: `mycluster`).
- `DOCKER_IMAGE_NAME`: Docker image name (default: `fast-demo`).
- `DOCKER_IMAGE_TAG`: Docker image tag (default: `value of API_VERSION`).
- `NGF_NAMESPACE`: Namespace for Nginx Gateway Fabric (default: `nginx-gateway`).
- `NGF_CRD_REF_VERSION`: Git reference (tag/branch) for Nginx Gateway Fabric CRDs (default: `v1.6.2` or as specified in Makefile).

## Running with Kubernetes (k3d)

This section describes how to run the application on a local k3d Kubernetes cluster using Nginx Gateway API, managed by the `Makefile`.

### Prerequisites

- Docker installed on your system.
- k3d installed (see [k3d installation guide](https://k3d.io/#installation)).
- kubectl installed (see [kubectl installation guide](https://kubernetes.io/docs/tasks/tools/install-kubectl/)).
- Helm installed (see [Helm installation guide](https://helm.sh/docs/intro/install/)).
- Make installed.
- `kustomize` installed (usually bundled with `kubectl` recent versions, or install separately).

### Setup and Deployment

1.  **Create k3d Cluster (if you don't have one):**

    ```bash
    make k3d-cluster-create
    ```

2.  **Install Kubernetes Gateway API CRDs:**
    This step uses `kustomize` to install CRDs directly from the Nginx Gateway Fabric repository.

    ```bash
    make k8s-install-gateway-crds
    ```

    You can customize the CRD version by setting `NGF_CRD_REF_VERSION` (e.g., `make k8s-install-gateway-crds NGF_CRD_REF_VERSION=v1.6.2`).

3.  **Install Nginx Gateway Fabric:**
    This installs Nginx Gateway Fabric using its official Helm chart.

    ```bash
    make install-nginx-gateway
    ```

    This will install it into the `nginx-gateway` namespace by default. You can change this with the `NGF_NAMESPACE` variable.

4.  **Build, Import, and Deploy the Application:**
    Provide your `K8S_INGRESS_IP`. You can also customize `API_VERSION`.

    ```bash
    make all-k8s K8S_INGRESS_IP=<your.actual.ip.address> API_VERSION=v21 # Or your desired version
    ```

    For example:

    ```bash
    make all-k8s K8S_INGRESS_IP=192.168.86.160 API_VERSION=beta01
    ```

    Individual steps:

    ```bash
    make docker-build
    make k3d-image-import
    make k8s-deploy K8S_INGRESS_IP=<your.ip.address> API_VERSION=<your.version>
    ```

    Monitor pod status with `kubectl get pods -n demo -w`.
    Check Gateway status with `kubectl get gateway -n demo fast-demo-gateway -o yaml`.
    Check HTTPRoute status with `kubectl get httproute -n demo fast-demo-httproute -o yaml`.

### Accessing the Application (on k3d)

Use `make k8s-access` with the same `K8S_INGRESS_IP` and `API_VERSION` used for deployment.

```bash
make k8s-access K8S_INGRESS_IP=<your.ip.address> API_VERSION=<your.version>
```

This will output URLs like (replace placeholders):

- **Main API Root**: `http://<your.ip.address>.nip.io/api/`
- **Main API Items (POST)**: `http://<your.ip.address>.nip.io/api/items/`
- **Sub API <your.version> Index**: `http://<your.ip.address>.nip.io/api/<your.version>/`
- **Sub API <your.version> Sub-route**: `http://<your.ip.address>.nip.io/api/<your.version>/sub`

Example using curl:

```bash
curl http://<your.ip.address>.nip.io/api/<your.version>/
```

### Cleaning Up Kubernetes Resources

To delete the application resources (Deployment, Service, Gateway, HTTPRoute, Namespace):

```bash
make k8s-delete K8S_INGRESS_IP=<your.ip.address> API_VERSION=<your.version>
```

_Note: `K8S_INGRESS_IP` and `API_VERSION` are needed to regenerate the manifest for targeted deletion._

To delete the application resources and the k3d cluster:

```bash
make clean-k8s K8S_INGRESS_IP=<your.ip.address> API_VERSION=<your.version>
```

To uninstall Nginx Gateway Fabric (if desired):

```bash
helm uninstall nginx-gateway-fabric -n $(make -s --no-print-directory help | grep "NGF_NAMESPACE " | awk '{print $NF}' | tr -d '()')
```

To uninstall the Gateway API CRDs (if desired, use with caution as other controllers might use them):

```bash
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=$(make -s --no-print-directory help | grep "NGF_CRD_REF_VERSION " | awk '{print $NF}' | tr -d '()')" | kubectl delete -f -
```

## Running with Docker (Local Development)

This section describes running the application directly with Docker, bypassing Kubernetes.

### Prerequisites

- Docker installed.
- Make installed.

### Build and Run the Docker Container

You can customize `API_VERSION`. The default is `v21`.

```bash
make docker-run-local API_VERSION=dev01
```

This will build the image if it doesn't exist and run the container in detached mode.

### Accessing the Application (Local Docker)

Use `make docker-access-local` (optionally with `API_VERSION`).

```bash
make docker-access-local API_VERSION=dev01
```

Or access directly (replace `<your.version>` with the path used, e.g., `dev01` or the default `v21`):

- **Main API Docs**: `http://localhost:8000/api/docs`
- **Main API Items (POST)**: `http://localhost:8000/api/items/`
- **Sub API <your.version> Docs**: `http://localhost:8000/api/<your.version>/docs`
- **Sub API <your.version> Index**: `http://localhost:8000/api/<your.version>/`
- **Sub API <your.version> Sub-route**: `http://localhost:8000/api/<your.version>/sub`

Example using curl:

```bash
curl http://localhost:8000/api/dev01/
```

To stop the local Docker container:

```bash
docker stop $(make -s --no-print-directory help | grep "DOCKER_IMAGE_NAME " | awk '{print $NF}' | tr -d '()')-local

```
