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

This application is deployed with GitHub Actions, Docker Hub, Terraform, AWS EKS, Helm, Argo CD, Prometheus, and Grafana.

### Run the pipeline from scratch

1. **GitHub secrets** (Settings → Secrets and variables → Actions):
   - `DOCKERHUB_USERNAME` — Docker Hub user (must match image repos in `helm-microservices/values.yaml`)
   - `DOCKERHUB_TOKEN` — Docker Hub access token
   - `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` — IAM user that can create VPC, EKS, IAM, and related resources in `us-east-2`

2. **Provision the cluster**  
   In GitHub Actions, run the **Terraform** workflow with `action = apply`. That creates the VPC, EKS cluster, node group, AWS Load Balancer Controller, NGINX Ingress, cert-manager, Argo CD, and kube-prometheus-stack. First apply often takes 15–25 minutes.

3. **Point DNS at the ALB**  
   After apply, get the ALB hostname and create records:
   - `challenge.yunus.in` → vote
   - `result.challenge.yunus.in` → result  

   ```bash
   kubectl get ingress -n voting
   ```

4. **Continuous delivery**  
   Push to `main` under `vote/`, `result/`, or `worker/`. The **Build, Test, and GitOps** workflow:
   - runs tests (result)
   - builds and pushes `vote` / `result` / `worker` images tagged with the GitHub run id
   - commits the new tags into `helm-microservices/values.yaml`  
   Argo CD watches that chart on `main` and syncs the `voting` namespace.

5. **Tear down**  
   Run the Terraform workflow with `action = destroy`. This incurs AWS cost while the cluster is up (node group defaults to two `t3.large` nodes).

### 1. **Version Control and GitHub Actions**
- The source code for the application is hosted on GitHub.
- GitHub Actions builds and pushes Docker images for `vote`, `result`, and `worker`.
- The result service runs unit tests before its image is published.

### 2. **Containerization with Docker**
- Each component of the application is containerized using Docker.
- Images are tagged with the GitHub Actions run id and pushed to Docker Hub.

### 3. **Infrastructure as Code with Terraform**
- Terraform provisions AWS infrastructure, including:
  - An EKS cluster for running the application
  - A VPC, subnets, and NAT/Internet gateways
  - IAM roles for nodes, Load Balancer Controller, and cluster autoscaler

### 4. **Kubernetes Deployment**
- The app is delivered with the Helm chart in `helm-microservices/` (GitOps via Argo CD).
- `k8s-specifications/` remains a simple local/Kubernetes alternative without the chart.

### 5. **Helm Chart for Simplified Management**
- `helm-microservices` manages deployments, services, and ALB Ingress.
- Image tags in `values.yaml` are the GitOps contract between CI and the cluster.

### 6. **Continuous Delivery with Argo CD**
- Terraform installs Argo CD and an Application that syncs `helm-microservices` from `main`.
- Tag updates on `main` trigger an automatic sync into the `voting` namespace.

### 7. **Ingress Configuration**
- AWS Load Balancer Controller exposes vote and result on internet-facing ALBs.
- Configure DNS for `challenge.yunus.in` (vote) and `result.challenge.yunus.in` (result).

### 8. **Monitoring and Observability**
- kube-prometheus-stack (Prometheus + Grafana) is installed in the `monitoring` namespace.
- Default Grafana admin password is in `terraform/values/kube-prometheus-stack.yaml` (change this for anything beyond a lab).

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
