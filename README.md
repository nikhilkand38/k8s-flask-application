# Flask Application on Kubernetes

A Flask-based web application that connects to a PostgreSQL database, deployed and managed using Kubernetes with Kind (Kubernetes in Docker).

## Project Overview

This project demonstrates:
- A Flask API with health check and user database endpoints
- PostgreSQL database with sample data
- Docker containerization for both app and database
- Kubernetes manifests for deployment and service configuration
- Kind cluster setup for local development

## Prerequisites

Before starting, ensure you have the following tools installed:

- **Docker**: [Install Docker](https://docs.docker.com/get-docker/)
- **kubectl**: [Install kubectl](https://kubernetes.io/docs/tasks/tools/)
- **Kind**: [Install Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- **Git**: [Install Git](https://git-scm.com/)

## Repository Structure

```
k8s-flask-application/
├── app.py                    # Flask application
├── Dockerfile               # Flask app Docker image
├── requirements.txt         # Python dependencies
├── db/
│   ├── Dockerfile          # PostgreSQL Docker image
│   ├── init.sql            # Database initialization script
│   └── k8s/
│       ├── deployment.yml  # Database deployment manifest
│       └── service.yml     # Database service manifest
├── k8s/
│   ├── kind.yml            # Kind cluster configuration
│   ├── deployment.yml      # Flask app deployment manifest
│   └── service.yml         # Flask app service manifest
└── .github/
    └── workflows/
        └── main.yml        # CI/CD pipeline
```

## Application Architecture

### Flask API Endpoints

- **`GET /health`** - Health check endpoint
  - Response: `{"status": "healthy"}`

- **`GET /users`** - Fetch users from database
  - Connects to PostgreSQL
  - Returns user data or error message

### Database

- **Type**: PostgreSQL 15
- **Database**: `appdb`
- **User**: `appuser`
- **Password**: `password`
- **Default Host in Kubernetes**: `flask-db` (service name)

### Docker Images

- **Flask App**: `flask-build:latest`
- **Database**: `db:latest`

## Step-by-Step Manual Setup

### Step 1: Clone the Repository

```bash
git clone <repository-url>
cd k8s-flask-application
```

### Step 2: Build Docker Images

Build the Flask application image:

```bash
docker build -t flask-build:latest .
```

Build the PostgreSQL database image:

```bash
docker build -t db:latest ./db
```

Verify the images were created:

```bash
docker images | grep -E 'flask-build|db'
```

**Expected Output:**
```
REPOSITORY     TAG       IMAGE ID      CREATED
flask-build    latest    <image-id>    <time>
db             latest    <image-id>    <time>
```

### Step 3: Create Kind Cluster

Create a Kubernetes cluster using the Kind configuration file (`k8s/kind.yml`):

```bash
kind create cluster --name dev-cluster --config k8s/kind.yml
```

This creates a Kind cluster with:
- 1 control-plane node
- 1 worker node

Verify the cluster was created:

```bash
kind get clusters
```

**Expected Output:**
```
dev-cluster
```

### Step 4: Load Docker Images into Kind

Load the Docker images into the Kind cluster so they can be used by Kubernetes:

```bash
kind load docker-image flask-build:latest --name dev-cluster
kind load docker-image db:latest --name dev-cluster
```

Verify the images are available in the cluster:

```bash
docker exec -it dev-cluster-control-plane crictl images
```

### Step 5: Set kubeconfig Context

Verify that kubectl is configured to use the dev-cluster:

```bash
kubectl cluster-info --context kind-dev-cluster
```

### Step 6: Apply Database Manifests

Deploy the PostgreSQL database first, starting with the deployment:

```bash
kubectl apply -f db/k8s/deployment.yml
```

This creates a deployment named `flask-deployment-db` based on the configuration:
- **Replicas**: 1
- **Image**: `db:latest`
- **Port**: 5432

Then, apply the database service:

```bash
kubectl apply -f db/k8s/service.yml
```

This creates a service named `flask-db` that:
- Exposes the database on port 5432
- Uses ClusterIP type for internal communication

### Step 7: Wait for Database to be Ready

Check if the database pod is running:

```bash
kubectl get pods
```

Wait for the pod to show status `Running`:

```bash
kubectl rollout status deployment/flask-deployment-db --timeout=180s
```

**Expected Output:**
```
deployment "flask-deployment-db" successfully rolled out
```

### Step 8: Apply Flask Application Manifests

Deploy the Flask application:

```bash
kubectl apply -f k8s/deployment.yml
```

This creates a deployment named `flask-deployment` based on the configuration:
- **Replicas**: 2
- **Image**: `flask-build:latest`
- **Port**: 5000
- **Environment Variables** (from the cluster):
  - `DB_HOST`: `flask-db` (resolves to the database service)
  - `DB_NAME`: `appdb`
  - `DB_USER`: `appuser`
  - `DB_PASSWORD`: `password`

Then, apply the Flask service:

```bash
kubectl apply -f k8s/service.yml
```

This creates a service named `flask-service` that:
- Exposes the Flask app on port 5000 internally
- Maps to NodePort 30080 externally

### Step 9: Wait for Flask Application to be Ready

Check if the Flask pods are running:

```bash
kubectl rollout status deployment/flask-deployment --timeout=180s
```

**Expected Output:**
```
deployment "flask-deployment" successfully rolled out
```

View all running resources:

```bash
kubectl get all
```

### Step 10: Verify Deployments

List all pods:

```bash
kubectl get pods
```

**Expected Output:**
```
NAME                                      READY   STATUS    RESTARTS   AGE
flask-deployment-<hash>-<pod-id>         1/1     Running   0          <time>
flask-deployment-<hash>-<pod-id>         1/1     Running   0          <time>
flask-deployment-db-<hash>-<pod-id>      1/1     Running   0          <time>
```

List all services:

```bash
kubectl get svc
```

**Expected Output:**
```
NAME            TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
flask-service   NodePort    <cluster-ip>    <none>        5000:30080/TCP <time>
flask-db        ClusterIP   <cluster-ip>    <none>        5432/TCP       <time>
kubernetes      ClusterIP   <cluster-ip>    <none>        443/TCP        <time>
```

### Step 11: Access the Application

#### Option A: Using Port-Forward (Temporary)

Forward the Flask service to your local machine:

```bash
kubectl port-forward service/flask-service 5000:5000
```

Then access the endpoints:

```bash
# Health check
curl http://127.0.0.1:5000/health

# Get users
curl http://127.0.0.1:5000/users
```

#### Option B: Using NodePort (Persistent)

Start a persistent port-forward in the background:

```bash
nohup kubectl port-forward service/flask-service 5000:5000 --address=0.0.0.0 >/tmp/persistent-port-forward.log 2>&1 &
```

Access from any machine on the network:

```bash
# Get the EC2 instance IP
EC2_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

# Health check
curl http://$EC2_IP:5000/health

# Get users
curl http://$EC2_IP:5000/users
```

### Step 12: Expected API Responses

**Health Check Response:**
```json
{
  "status": "healthy"
}
```

**Users API Response:**
```json
{
  "message": "Database connection successful",
  "result": 1
}
```

## Monitoring and Debugging

### View Pod Logs

View logs from the Flask app:

```bash
kubectl logs -f deployment/flask-deployment
```

View logs from the database:

```bash
kubectl logs -f deployment/flask-deployment-db
```

### Describe Pod Details

Get detailed information about a pod:

```bash
kubectl describe pod <pod-name>
```

Example:
```bash
kubectl describe pod flask-deployment-<hash>-<pod-id>
```

### Execute Commands in a Pod

Execute commands inside a pod for debugging:

```bash
kubectl exec -it <pod-name> -- /bin/bash
```

## Cleanup

### Stop Port-Forward

Kill the persistent port-forward process:

```bash
pkill -f "kubectl port-forward"
```

### Delete Kubernetes Resources

Delete the Flask service and deployment:

```bash
kubectl delete -f k8s/service.yml
kubectl delete -f k8s/deployment.yml
```

Delete the database service and deployment:

```bash
kubectl delete -f db/k8s/service.yml
kubectl delete -f db/k8s/deployment.yml
```

Or delete all at once:

```bash
kubectl delete -f k8s/ -f db/k8s/
```

### Delete Kind Cluster

Delete the entire Kind cluster:

```bash
kind delete cluster --name dev-cluster
```

### Remove Docker Images

Remove the Docker images:

```bash
docker rmi flask-build:latest db:latest
```

## Kubernetes Manifest Reference

### Flask App Deployment (`k8s/deployment.yml`)

Defines how the Flask application is deployed:
- Creates 2 replicas for high availability
- Uses the `flask-build:latest` image
- Exposes port 5000
- Sets `imagePullPolicy: IfNotPresent` to use local images

### Flask Service (`k8s/service.yml`)

Exposes the Flask application:
- Type: `NodePort` (accessible from outside the cluster)
- Internal port: 5000
- External port: 30080
- Selector: `app: flask`

### Database Deployment (`db/k8s/deployment.yml`)

Defines how the PostgreSQL database is deployed:
- Creates 1 replica
- Uses the `db:latest` image
- Exposes port 5432
- Environment variables for database setup

### Database Service (`db/k8s/service.yml`)

Exposes the database within the cluster:
- Type: `ClusterIP` (internal only)
- Port: 5432
- Selector: `app: flask-db`

## Environment Variables

The Flask application uses the following environment variables (with defaults):

```
DB_HOST=flask-db          # Database hostname
DB_NAME=appdb             # Database name
DB_USER=appuser           # Database user
DB_PASSWORD=password      # Database password
```

These are configured in `app.py` and can be overridden when deploying to different environments.

## CI/CD Pipeline

The repository includes a GitHub Actions workflow (`.github/workflows/main.yml`) that automates:
1. Building Docker images
2. Creating a Kind cluster
3. Loading images into the cluster
4. Applying Kubernetes manifests
5. Verifying API endpoints
6. Preserving the cluster for manual testing

Run the workflow manually from the GitHub Actions tab or trigger it via:
- Push to `main` branch
- Pull requests to `main` branch

## Troubleshooting

### Pods not starting

Check pod status and events:

```bash
kubectl describe pod <pod-name>
kubectl get events
```

### Database connection refused

Ensure the database pod is running:

```bash
kubectl get pods -l app=flask-db
```

Verify the service DNS is resolvable:

```bash
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup flask-db
```

### Port-forward not working

Kill existing port-forward processes:

```bash
pkill -f "kubectl port-forward"
```

Start a new one:

```bash
kubectl port-forward service/flask-service 5000:5000 --address=0.0.0.0
```

### Image pull errors

Ensure images are loaded into Kind:

```bash
kind load docker-image flask-build:latest --name dev-cluster
kind load docker-image db:latest --name dev-cluster
```

## Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kind Documentation](https://kind.sigs.k8s.io/)
- [Flask Documentation](https://flask.palletsprojects.com/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Docker Documentation](https://docs.docker.com/)

---

**Last Updated**: August 2026
