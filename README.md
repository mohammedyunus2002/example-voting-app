# Example Voting App

A simple distributed application running across multiple Docker containers.

## Getting Started

Download [Docker Desktop](https://www.docker.com/products/docker-desktop) for Mac or Windows. [Docker Compose](https://docs.docker.com/compose) will be automatically installed. On Linux, make sure you have the latest version of [Compose](https://docs.docker.com/compose/install/).

This solution uses Python, Node.js, .NET, with Redis for messaging and Postgres for storage.

Run in this directory to build and run the app:

```shell
docker compose up
```

The `vote` app will be running at [http://localhost:8080](http://localhost:8080), and the `results` app will be at [http://localhost:8081](http://localhost:8081).

Alternately, if you want to run it on a [Docker Swarm](https://docs.docker.com/engine/swarm/), first make sure you have a swarm. If you don't, run:

```shell
docker swarm init
```

Once you have your swarm, in this directory run:

```shell
docker stack deploy --compose-file docker-stack.yml vote
```

## Run the App in Kubernetes

The folder `k8s-specifications` contains the YAML specifications of the Voting App's services.

Run the following command to create the deployments and services. Note it will create these resources in your current namespace (`default` if you haven't changed it):

```shell
kubectl create -f k8s-specifications/
```

The `vote` web app is then available on port 31000 on each host of the cluster, and the `result` web app is available on port 31001.

To remove them, run:

```shell
kubectl delete -f k8s-specifications/
```

## Deployment Using CI/CD

This application was deployed using a robust CI/CD pipeline leveraging GitHub Actions, Docker, Terraform, AWS, Kubernetes, Helm, and Argo CD. Below is an overview of the process:

### 1. **Version Control and GitHub Actions**
- The source code for the application is hosted on GitHub.
- GitHub Actions was configured to automate building and pushing Docker images for each component of the application (`vote`, `result`, and `worker`).
- The workflow also runs unit tests to ensure code quality before deployment.

### 2. **Containerization with Docker**
- Each component of the application is containerized using Docker.
- Docker images are tagged with unique identifiers (e.g., Git commit SHA) and pushed to Docker Hub for easy access during deployment.

### 3. **Infrastructure as Code with Terraform**
- Terraform was used to provision the AWS infrastructure, including:
  - An EKS (Elastic Kubernetes Service) cluster for running the application.
  - A VPC, subnets, and security groups to ensure secure networking.
  - S3 buckets and IAM roles for storage and permissions management.

### 4. **Kubernetes Deployment**
- The application was deployed to the EKS cluster using Kubernetes manifests stored in the `k8s-specifications` directory.
- Ingress was configured using an NGINX Ingress Controller to expose the application externally.

### 5. **Helm Chart for Simplified Management**
- A custom Helm chart was created to manage the application's deployments, services, and ingress resources.
- This Helm chart simplifies updates and scaling by providing a unified configuration for the entire application.

### 6. **Continuous Delivery with Argo CD**
- Argo CD was set up for declarative GitOps-style continuous delivery.
- The GitHub repository is the single source of truth, and any changes to Kubernetes manifests trigger automatic deployments to the cluster.

### 7. **Ingress Configuration**
- The AWS ALB Ingress Controller is used to route external traffic to the `vote` and `result` web applications.
- The domain `challenge.yunus.in` was configured with DNS records pointing to the AWS ALB (Application Load Balancer) created by the Ingress Controller.

### 8. **Monitoring and Observability**
- Prometheus and Grafana were configured to monitor the cluster and application metrics.
- Dashboards provide real-time insights into application performance and resource utilization.

## Architecture

![Architecture diagram](architecture.excalidraw.png)

- **Vote App**: A front-end web app in [Python](/vote) that lets users vote between two options.
- **Redis**: A messaging queue that collects new votes.
- **Worker**: A back-end service written in .NET that processes votes and stores them in a Postgres database.
- **Postgres**: A relational database for persistent storage, backed by a Docker volume.
- **Result App**: A Node.js web app that displays voting results in real time.

## Notes

- The voting application only accepts one vote per client browser. It does not register additional votes if a vote has already been submitted from a client.
- This is a simple example of a distributed application. While not designed for production, it demonstrates core concepts such as containerization, orchestration, and continuous delivery.
