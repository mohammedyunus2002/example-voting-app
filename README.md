
# Example Voting App

A distributed voting application built with microservices. This project demonstrates containerization, orchestration, CI/CD automation, GitOps deployment, AWS infrastructure provisioning, and monitoring with Kubernetes.

## Table of Contents

- [Architecture](#architecture)
- [Technology Stack](#technology-stack)
- [Prerequisites](#prerequisites)
- [Run Locally with Docker Compose](#run-locally-with-docker-compose)
- [Deploy with Docker Swarm](#deploy-with-docker-swarm)
- [Deploy to Kubernetes](#deploy-to-kubernetes)
- [CI/CD and GitOps](#cicd-and-gitops)
- [AWS Infrastructure](#aws-infrastructure)
- [Monitoring and Observability](#monitoring-and-observability)
- [Configuration and Secrets](#configuration-and-secrets)
- [Cleanup](#cleanup)
- [Known Limitations](#known-limitations)
- [License](#license)

## Architecture

The application consists of five main services:

| Service | Responsibility | Technology |
|---|---|---|
| Vote | Accepts votes from users | Python, Flask |
| Redis | Queues incoming votes | Redis |
| Worker | Processes votes and stores them | C#, .NET |
| PostgreSQL | Persists vote data | PostgreSQL |
| Result | Displays live voting results | Node.js, Express, Socket.IO |

### Data Flow

1. Users submit their votes through the Vote application.
2. The Vote service pushes vote messages into a Redis queue.
3. The Worker consumes messages from Redis.
4. The Worker writes vote data to PostgreSQL.
5. The Result service queries PostgreSQL and broadcasts updated results through Socket.IO.

## Technology Stack

| Category | Technologies |
|---|---|
| Application | Python, Flask, C#, .NET, Node.js, Express |
| Data and Messaging | Redis, PostgreSQL |
| Containers | Docker, Docker Compose |
| Orchestration | Docker Swarm, Kubernetes |
| Packaging | Helm |
| Cloud Infrastructure | AWS, Amazon EKS, VPC, IAM |
| Infrastructure as Code | Terraform |
| CI/CD | GitHub Actions |
| GitOps | Argo CD |
| Ingress | AWS Load Balancer Controller, NGINX Ingress |
| Monitoring | Prometheus, Grafana, kube-prometheus-stack |

## Prerequisites

### Local Development

- Git
- Docker Engine
- Docker Compose

### AWS and Kubernetes Deployment

- AWS CLI
- Terraform
- kubectl
- Helm
- An AWS account with the required permissions
- GitHub and Docker Hub accounts
- DNS access for the configured application domains

## Run Locally with Docker Compose

### 1. Clone the Repository

```bash
git clone https://github.com/mohammedyunus2002/example-voting-app.git
cd example-voting-app
```

### 2. Start the Application

```bash
docker compose up --build
```

### 3. Access the Applications

| Application | URL |
|---|---|
| Voting interface | http://localhost:8080 |
| Results interface | http://localhost:8081 |

### 4. Run the Optional Seed Service

```bash
docker compose --profile seed up --build
```

### 5. Stop the Application

```bash
docker compose down
```

To remove the containers and named volumes:

```bash
docker compose down --volumes
```

> **Warning:** Removing volumes can permanently delete locally stored database data.

### Run with Prebuilt Images

```bash
docker compose -f docker-compose.images.yml up -d
```

This configuration uses the image references defined in `docker-compose.images.yml`.

## Deploy with Docker Swarm

Initialize Docker Swarm:

```bash
docker swarm init
```

Deploy the application stack:

```bash
docker stack deploy --compose-file docker-stack.yml vote
```

Check the running services:

```bash
docker stack services vote
```

Check the containers:

```bash
docker stack ps vote
```

Remove the stack:

```bash
docker stack rm vote
```

## Deploy to Kubernetes

The repository contains Kubernetes manifests in the `k8s-specifications/` directory.

### 1. Apply the Manifests

```bash
kubectl apply -f k8s-specifications/
```

### 2. Verify the Deployment

```bash
kubectl get deployments
kubectl get pods
kubectl get services
```

### 3. Access the Applications

If the configured NodePorts are `31000` for voting and `31001` for results:

- Voting: `http://<node-ip>:31000`
- Results: `http://<node-ip>:31001`

Verify the actual NodePort values in the Kubernetes service manifests.

### 4. Delete the Resources

```bash
kubectl delete -f k8s-specifications/
```

## CI/CD and GitOps

GitHub Actions automates application testing, image building, publishing, and deployment configuration updates.

### Application CI/CD Workflow

Workflow file:

```text
.github/workflows/ci.yaml
```

The workflow can:

1. Detect changes to application services.
2. Run Result service tests when relevant files change.
3. Build Docker images for changed services.
4. Publish images to Docker Hub for eligible non-pull-request runs.
5. Tag images using the GitHub Actions run ID.
6. Update image tags in the Helm values file.
7. Commit updated deployment configuration to the repository.

### GitOps with Argo CD

Argo CD watches the repository's `main` branch and the `helm-microservices/` directory.

When the Helm deployment configuration changes, Argo CD can synchronize the desired application state with the Kubernetes cluster.

The configured application namespace is:

```text
voting
```

Automated synchronization, pruning, and self-healing are configured in the Argo CD application values.

### Required GitHub Secrets

Configure the following secrets in your GitHub repository settings:

| Secret | Purpose |
|---|---|
| `DOCKERHUB_USERNAME` | Docker Hub username |
| `DOCKERHUB_TOKEN` | Docker Hub access token |
| `AWS_ACCESS_KEY_ID` | AWS authentication for Terraform |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key for Terraform |

Use narrowly scoped credentials. Where supported, prefer GitHub Actions OIDC with AWS IAM role assumption instead of long-lived AWS access keys.

### Terraform Workflow

Workflow file:

```text
.github/workflows/terraform.yaml
```

The workflow supports manually triggered Terraform operations such as:

- Plan
- Apply
- Destroy

**Important:** Configure persistent Terraform state and state locking before relying on repeated workflow runs. Do not depend on local state files stored on temporary GitHub-hosted runners.

## AWS Infrastructure

The `terraform/` directory contains the Infrastructure as Code used to provision the AWS environment.

### Infrastructure Components

The configuration includes:

- Amazon VPC
- Public and private subnets across two Availability Zones
- Internet Gateway and NAT Gateway
- Amazon EKS cluster
- EKS managed node group
- IAM users, roles, policies, and cluster access configuration
- AWS Load Balancer Controller
- NGINX Ingress Controller
- cert-manager
- EBS and EFS CSI drivers
- Secrets Store CSI Driver
- Cluster Autoscaler
- Metrics Server
- Argo CD
- Prometheus and Grafana

### Default Configuration

| Setting | Value |
|---|---|
| AWS region | `us-east-2` |
| Environment | `staging` |
| EKS cluster name | `staging-demo` |
| Kubernetes version configured in Terraform | `1.29` |
| EC2 instance type | `t3.large` |
| Desired worker nodes | `2` |
| Minimum worker nodes | `1` |
| Maximum worker nodes | `10` |

> **Important:** Verify the configured Kubernetes version and dependency versions against currently supported AWS EKS versions before provisioning.

### Provision Infrastructure

1. Open the repository's **Actions** tab.
2. Select the Terraform workflow.
3. Run the plan operation and review the proposed changes.
4. Run apply only after reviewing the plan.
5. Wait for the cluster and dependent services to become ready.

Infrastructure provisioning creates billable AWS resources. Review potential costs before applying the configuration.

### Application Domains

| Service | Hostname |
|---|---|
| Vote | `challenge.yunus.in` |
| Result | `result.challenge.yunus.in` |

Configure DNS records to point to the provisioned ingress endpoint.

Review the ingress configuration before exposing services publicly. Configure HTTPS and valid TLS certificates before using the deployment for production workloads.

## Monitoring and Observability

The Terraform configuration installs a monitoring stack based on Prometheus and Grafana.

### Components

- **Prometheus:** Collects and stores metrics.
- **Grafana:** Provides dashboards for metrics visualization.
- **Metrics Server:** Supplies resource metrics for Kubernetes.
- **Cluster Autoscaler:** Adjusts the number of worker nodes based on scheduling requirements.

### Configuration Notes

The current monitoring configuration includes:

- Prometheus retention of approximately three days.
- Prometheus persistence disabled.
- Grafana persistence disabled.
- Alertmanager disabled.
- A configured Grafana administrator password that should be replaced with a securely managed credential.

For longer-term monitoring, configure persistent storage, secure credentials, appropriate retention, and alerting.

## Configuration and Secrets

Review application and infrastructure configuration before deploying to a shared or public environment.

### Recommended Practices

- Never commit real credentials, API keys, or access tokens.
- Use Kubernetes Secrets or an appropriate external secrets-management solution.
- Restrict IAM permissions to the minimum required.
- Avoid hardcoded database passwords in deployment manifests.
- Enable HTTPS and configure valid TLS certificates.
- Restrict access to Argo CD, Grafana, and administrative interfaces.
- Review public ingress rules and security groups.
- Configure persistent storage for database data that must survive pod replacement.
- Validate Kubernetes RBAC and EKS access policies for every user and role.

The presence of a Secrets Store CSI Driver does not automatically mean that application secrets are integrated with an external provider. Verify the provider configuration, IAM permissions, secret objects, and pod mounts.

## Cleanup

Destroy infrastructure only when it is no longer needed.

Use the Terraform workflow's destroy operation after reviewing the resources that will be removed.

Before destroying the environment:

1. Confirm that no workloads or data need to be retained.
2. Back up required database data and configuration.
3. Review Terraform's destroy plan.
4. Run the destroy operation.
5. Verify that the associated AWS resources have been removed.

> **Warning:** Destroying infrastructure can delete application resources and data. NAT Gateways, load balancers, EKS clusters, and EC2 instances can incur charges while they exist.

## Known Limitations

This project is intended for learning and demonstration rather than production use.

Before production deployment, address the following areas:

- **Data persistence:** The Kubernetes database configuration does not currently provide durable persistent storage.
- **Secrets:** Credentials must be securely managed rather than hardcoded.
- **Access control:** Review IAM policies, EKS access entries, Kubernetes RBAC, and administrative access.
- **Voting integrity:** Add appropriate identity, validation, and duplicate-vote protections for the intended use case.
- **Availability:** Review replicas, health checks, resource requests and limits, and recovery procedures.
- **Networking:** Verify ingress behavior, public exposure, TLS, and security group rules.
- **Monitoring:** Configure persistent metrics storage, alerting, and appropriate retention.
- **Terraform state:** Use a persistent backend and state locking for repeatable infrastructure management.
- **Version compatibility:** Keep Kubernetes, Terraform providers, Helm charts, and container images on supported versions.
- **Recovery:** Document backup, restore, and disaster-recovery procedures.

## License

See the [`LICENSE`](LICENSE) file for license information.
