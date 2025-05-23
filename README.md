# Fast Demo API

This project is a FastAPI application.

## Running with Docker

### Prerequisites

- Docker installed on your system.

### Build the Docker Image

Navigate to the project's root directory (where the `Dockerfile` is located) and run the following command to build the Docker image:

```bash
docker build -t fast-demo .
```

### Run the Docker Container

Once the image is built, you can run it as a container:

```bash
docker run -p 8000:8000 fast-demo
```

This command will:

- Run the container in the foreground.
- Map port 8000 of the container to port 8000 on your host machine.

### Accessing the Application

Once the container is running, you can access the API endpoints:

- **Main API Root**: `http://localhost:8000/api/fast-demo/`
- **Main API Items (POST)**: `http://localhost:8000/api/fast-demo/items/`
- **Sub API v21 Index**: `http://localhost:8000/api/fast-demo/v21/`
- **Sub API v21 Sub-route**: `http://localhost:8000/api/fast-demo/v21/sub`

You can open these URLs in your browser or use an API client like Postman or curl. For example, to check the main API root:

```bash
curl http://localhost:8000/api/fast-demo/
```
