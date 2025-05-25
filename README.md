# Fast Demo API

This project is a FastAPI application. This guide explains how to run it using Kubernetes (with k3d and Nginx Ingress) or Docker directly.

## Using the Makefile

A `Makefile` is provided to simplify common tasks. Run `make help` to see available targets and options.
You will need to have `make` installed on your system.

Key variables for the Makefile:

- `K8S_INGRESS_IP`: Your desired Ingress IP for Kubernetes (e.g., `192.168.86.160`). This **must** be provided for Kubernetes deployment targets. Example: `make k8s-deploy K8S_INGRESS_IP=your.ip.address`.
- `API_VERSION`: The path prefix for the sub-API (default: `v21`). Example: `make k8s-deploy API_VERSION=v22`.
- `K8S_CLUSTER_NAME`: Name for the k3d cluster (default: `mycluster`).
- `DOCKER_IMAGE_NAME`: Docker image name (default: `fast-demo`).
- `DOCKER_IMAGE_TAG`: Docker image tag (default: `latest`).

## Running with Kubernetes (k3d)

This section describes how to run the application on a local k3d Kubernetes cluster using Nginx Ingress, managed by the `Makefile`.

### Prerequisites

- Docker installed on your system.
- k3d installed (see [k3d installation guide](https://k3d.io/#installation)).
- kubectl installed (see [kubectl installation guide](https://kubernetes.io/docs/tasks/tools/install-kubectl/)).
- Helm installed (see [Helm installation guide](https://helm.sh/docs/intro/install/)).
- Make installed.

### Setup and Deployment

1.  **Create k3d Cluster (if you don't have one):**

    ```bash
    make k3d-cluster-create
    ```

2.  **Install Nginx Ingress Controller (if not already installed in your cluster):**

    ```bash
    make install-nginx
    ```

3.  **Build, Import, and Deploy the Application:**
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

### Accessing the Application (on k3d)

Use `make k8s-access` with the same `K8S_INGRESS_IP` and `API_VERSION` used for deployment.

```bash
make k8s-access K8S_INGRESS_IP=<your.ip.address> API_VERSION=<your.version>
```

This will output URLs like (replace placeholders):

- **Main API Root**: `http://<your.ip.address>.nip.io/api/`
- **Sub API <your.version> Index**: `http://<your.ip.address>.nip.io/api/<your.version>/`
- **Sub API <your.version> Sub-route**: `http://<your.ip.address>.nip.io/api/<your.version>/sub`

Example using curl:

```bash
curl http://<your.ip.address>.nip.io/api/<your.version>/
```

### Cleaning Up Kubernetes Resources

```bash
make k8s-delete K8S_INGRESS_IP=<your.ip.address> API_VERSION=<your.version>
make clean-k8s K8S_INGRESS_IP=<your.ip.address> API_VERSION=<your.version>
```

## Running with Docker (Local Development)

### Prerequisites

- Docker installed.
- Make installed.

### Build and Run the Docker Container

You can customize `API_VERSION`.

```bash
make docker-run-local API_VERSION=dev01
```

### Accessing the Application (Local Docker)

Use `make docker-access-local` (optionally with `API_VERSION`).

```bash
make docker-access-local API_VERSION=dev01
```

Or access directly (replace `<your.version>` with the path used, e.g., `dev01`):

- **Main API Docs**: `http://localhost:8000/api/docs`
- **Sub API <your.version> Docs**: `http://localhost:8000/api/<your.version>/docs`
- **Sub API <your.version> Index**: `http://localhost:8000/api/<your.version>/`
- **Sub API <your.version> Sub-route**: `http://localhost:8000/api/<your.version>/sub`

Example using curl:

```bash
curl http://localhost:8000/api/<your.version>/
```
