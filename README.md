# Fast Demo API (with Nginx Gateway API and Kubernetes Operator)

This project is a FastAPI application. This guide explains how to run it using Kubernetes (with k3d, Nginx Gateway API, and the FastAPIManaged Operator) or Docker directly.

## Using the Makefile

A `Makefile` is provided to simplify common tasks. Run `make help` to see available targets and options.
You will need to have `make` installed on your system.

Key variables for the Makefile:

- `K8S_INGRESS_IP`: Your desired IP for the Kubernetes Gateway. This **must be configured in the `FastAPIManaged` Custom Resource (`spec.ingressIP`)**. Provide this variable to `make k8s-access` for displaying access URLs. Example: `make k8s-access K8S_INGRESS_IP=your.ip.address`.
- `API_VERSION`: The version of your application. This is used as the application's Docker image tag (e.g., `fast-demo:v21`) and **must be configured in the `FastAPIManaged` Custom Resource (`spec.apiVersion`)**. Provide this to `make k8s-access`. Default: `v21`.
- `APP_NAMESPACE`: The Kubernetes namespace where the application resources will be deployed by the operator (default: `demo`). This **must match `spec.namespace` in your `FastAPIManaged` CR and the namespace where you apply the CR.**
- `DOCKER_IMAGE_NAME`: Name of the application's Docker image (default: `fast-demo`). This **should match `spec.applicationImage` in your `FastAPIManaged` CR.**
- `K8S_CLUSTER_NAME`: Name for the k3d cluster (default: `mycluster`).
- `OPERATOR_PROJECT_DIR`: Path to the operator project (default: `FastAPIOperator`).
- `OPERATOR_IMG_NAME`, `OPERATOR_IMG_TAG`: Operator's Docker image name and tag.
- `OPERATOR_NAMESPACE`: Namespace where the operator controller is deployed (default: `fastapioperator-system`).
- `CR_SAMPLE_YAML`: Path to the `FastAPIManaged` Custom Resource sample YAML.
- `NGF_NAMESPACE`: Namespace for Nginx Gateway Fabric (default: `nginx-gateway`).
- `NGF_CRD_REF_VERSION`: Git reference for Nginx Gateway Fabric CRDs.

## Running with Kubernetes (k3d and FastAPIManaged Operator)

This section describes how to run the application on a local k3d Kubernetes cluster using Nginx Gateway API, managed by the FastAPIManaged Operator.

### Prerequisites

- Docker installed on your system.
- k3d installed (see [k3d installation guide](https://k3d.io/#installation)).
- kubectl installed (see [kubectl installation guide](https://kubernetes.io/docs/tasks/tools/install-kubectl/)).
- Helm installed (see [Helm installation guide](https://helm.sh/docs/intro/install/)).
- Make installed.
- `kustomize` installed (usually bundled with `kubectl` recent versions, or install separately).
- The `FastAPIOperator` project (sibling directory `../FastAPIOperator`) must be set up and its Go dependencies vendored.

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

3.  **Install Nginx Gateway Fabric:**
    This installs Nginx Gateway Fabric using its official Helm chart.

    ```bash
    make install-nginx-gateway
    ```

4.  **Prepare your `FastAPIManaged` Custom Resource:**
    Edit the sample CR file: `FastAPIOperator/config/samples/dev_v1alpha1_fastapimanaged.yaml`.
    Ensure `spec.namespace`, `spec.applicationImage`, `spec.apiVersion`, and `spec.ingressIP` are set to your desired values. For example:

    ```yaml
    # FastAPIOperator/config/samples/dev_v1alpha1_fastapimanaged.yaml
    apiVersion: dev.web.api/v1alpha1
    kind: FastAPIManaged
    metadata:
      name: fastapimanaged-sample # CR name
      # namespace: demo # CR will be applied to APP_NAMESPACE via kubectl -n
    spec:
      namespace: "demo" # Matches APP_NAMESPACE
      applicationImage: "fast-demo" # Matches DOCKER_IMAGE_NAME
      apiVersion: "v21" # Matches API_VERSION
      replicas: 1
      ingressIP: "192.168.86.160" # Your K8S_INGRESS_IP
      gatewayClassName: "nginx"
      httpRoutePathPrefix: "/api"
      servicePort: 8000
      containerPort: 8000
    # status: {} # Add if CRD requires it and not omitempty
    ```

5.  **Build, Import, and Deploy the Application and Operator:**
    Provide `K8S_INGRESS_IP` and `API_VERSION` for the `k8s-access` step. These should match your CR.

    ```bash
    make all-k8s K8S_INGRESS_IP=<your.actual.ip.address> API_VERSION=<app-version>
    ```

    For example:

    ```bash
    make all-k8s K8S_INGRESS_IP=192.168.86.160 API_VERSION=v21
    ```

    This `all-k8s` target performs the following:

    - Builds the application Docker image (`make docker-build`).
    - Imports the application image into k3d (`make k3d-image-import`).
    - Builds the operator Docker image (`make operator-build`).
    - Imports the operator image into k3d (`make operator-k3d-image-import`).
    - Installs operator CRDs (`make operator-install-crds`).
    - Deploys the operator controller (`make operator-deploy`).
    - Deploys the `FastAPIManaged` Custom Resource (`make app-cr-deploy`).
    - Shows access information (`make k8s-access`).

    **Individual Steps (if not using `all-k8s`):**

    ```bash
    # 1. Build and import application image
    make docker-build API_VERSION=v21
    make k3d-image-import API_VERSION=v21

    # 2. Build and import operator image
    make operator-build OPERATOR_IMG_TAG=v0.0.1
    make operator-k3d-image-import OPERATOR_IMG_TAG=v0.0.1

    # 3. Install operator CRDs (if not already present)
    make operator-install-crds

    # 4. Deploy the operator
    make operator-deploy OPERATOR_IMG_TAG=v0.0.1

    # 5. Deploy the application via Custom Resource
    #    (Ensure FastAPIOperator/config/samples/dev_v1alpha1_fastapimanaged.yaml is configured)
    make app-cr-deploy APP_NAMESPACE=demo
    ```

6.  **Monitor Status:**
    - Operator pods: `kubectl get pods -n $(OPERATOR_NAMESPACE) -w`
    - Operator logs: `kubectl logs -n $(OPERATOR_NAMESPACE) -l control-plane=controller-manager -f`
    - `FastAPIManaged` CR: `kubectl get fastapimanaged -n $(APP_NAMESPACE)`
    - Describe CR: `kubectl describe fastapimanaged $(CR_NAME) -n $(APP_NAMESPACE)`
    - Application resources created by operator: `kubectl get deployment,service,gateway,httproute,pods -n $(APP_NAMESPACE)`

### Accessing the Application (on k3d)

Use `make k8s-access` with the `K8S_INGRESS_IP` and `API_VERSION` that match your deployed `FastAPIManaged` CR.

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
curl http://192.168.86.160.nip.io/api/v21/
```

### Cleaning Up Kubernetes Resources

1.  **Delete the application (FastAPIManaged CR):**

    ```bash
    make app-cr-delete APP_NAMESPACE=demo
    ```

2.  **Undeploy the operator controller:**

    ```bash
    make operator-undeploy
    ```

3.  **(Optional) Uninstall operator CRDs:**

    ```bash
    make operator-uninstall-crds
    ```

4.  **Delete the k3d cluster and all application/operator resources:**
    ```bash
    make clean-k8s
    ```
    (This runs `app-cr-delete`, `operator-undeploy`, then `k3d-cluster-delete`. You might run `operator-uninstall-crds` separately if needed before `k3d-cluster-delete`.)

To uninstall Nginx Gateway Fabric (if desired):

```bash
helm uninstall nginx-gateway-fabric -n $(NGF_NAMESPACE)
```

To uninstall the Gateway API CRDs (if desired, use with caution):

```bash
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=$(NGF_CRD_REF_VERSION)" | kubectl delete -f -
```

## Running with Docker (Local Development)

This section describes running the application directly with Docker, bypassing Kubernetes. This part remains unchanged.

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
docker stop $(DOCKER_IMAGE_NAME)-local
```
