# Elasticsearch on Kubernetes Lab (ECK)

A hands-on lab deploying Elasticsearch on Kubernetes using the
Elastic Cloud on Kubernetes (ECK) operator — the same technology
powering Elastic Cloud's hosted and serverless offerings.

Built on a multi-VPC AWS infrastructure managed entirely with
Terraform, accessed via AWS SSM Session Manager (zero open ports,
zero SSH keys).

> **Related project**: This lab builds on the networking
> foundations established in
> [vpc-peering-lab](https://github.com/pham0158/vpc-peering-lab)

## Architecture

```
┌─────────────────────────────────┐     ┌─────────────────────────────────┐
│       VPC-A (10.2.0.0/16)       │     │       VPC-B (10.3.0.0/16)       │
│                                 │     │                                 │
│  ┌──────────────────────────┐   │     │  ┌──────────────────────────┐   │
│  │  K8s Control Plane       │   │     │  │  K8s Worker Node         │   │
│  │  t3.medium (4GB RAM)     │   │     │  │  t3.medium (4GB RAM)     │   │
│  │                          │   │     │  │                          │   │
│  │  ┌──────────────────┐    │   │     │  │  ┌──────────────────┐    │   │
│  │  │  ECK Operator    │    │   │     │  │  │  Elasticsearch   │    │   │
│  │  │  elastic-system  │    │   │     │  │  │  StatefulSet     │    │   │
│  │  └──────────────────┘    │   │     │  │  └──────────────────┘    │   │
│  │                          │   │     │  │                          │   │
│  │  ┌──────────────────┐    │   │     │  │  ┌──────────────────┐    │   │
│  │  │  Kibana          │    │   │     │  │  │  SSM Endpoints   │    │   │
│  │  │  Deployment      │    │   │     │  │  │  x3              │    │   │
│  │  └──────────────────┘    │   │     │  │  └──────────────────┘    │   │
│  └──────────────────────────┘   │     │  └──────────────────────────┘   │
└──────────────┬──────────────────┘     └──────────────┬──────────────────┘
               └──────────── VPC Peering ───────────────┘
```

## What This Demonstrates

### ECK Operator Pattern
- Elasticsearch deployed as a Kubernetes Custom Resource (CRD)
- ECK operator manages the full lifecycle automatically
- StatefulSets for stable pod identity and persistent storage
- Auto-provisioned TLS certificates and credentials
- Self-healing: deleted pods automatically recreated with data intact

### Enterprise Patterns
- Zero-trust access via AWS SSM (no port 22, no SSH keys)
- Private subnets with VPC Interface Endpoints (PrivateLink)
- Infrastructure as Code — 100% Terraform
- t3.medium nodes sized for real Elasticsearch workloads
- Persistent storage via EBS-backed PersistentVolumeClaims

## Tech Stack

| Category | Technology |
|---|---|
| Cloud | AWS (us-east-1) |
| IaC | Terraform ~> 5.0 |
| Compute | EC2 t3.medium (AL2023) |
| Container Runtime | containerd |
| Kubernetes | v1.29 (kubeadm) |
| CNI | Flannel VXLAN |
| Operator | ECK 2.14.0 |
| Search | Elasticsearch 8.14.0 |
| Visualization | Kibana 8.14.0 |
| Access | AWS SSM Session Manager |

## Project Phases

| Phase | Description | Cost |
|---|---|---|
| 0 | Project scaffold | $0 |
| 1 | Infrastructure + K8s bootstrap | ~$0.20 |
| 2 | ECK operator install | ~$0.10 |
| 3 | Elasticsearch deployment | ~$0.20 |
| 4 | Kibana deployment | ~$0.15 |
| 5 | Data indexing + search API | ~$0.15 |
| 6 | Self-healing + resilience testing | ~$0.10 |
| 7 | Documentation + polish | $0 |

## Prerequisites

- AWS account with programmatic access
- AWS CLI configured
- Terraform >= 1.0
- Session Manager Plugin

```bash
brew install awscli
brew tap hashicorp/tap && brew install hashicorp/tap/terraform
brew install --cask session-manager-plugin
```

## Quick Start

```bash
# Deploy infrastructure
cd terraform
terraform init
terraform apply

# Daily workflow
cd ..
./cluster.sh start    # morning
./cluster.sh stop     # evening
./cluster.sh status   # check anytime

# Connect to control plane
./cluster.sh connect-cp

# Tear down
./cluster.sh destroy
```

## Repository Structure

```
elasticsearch-k8s-lab/
├── README.md
├── cluster.sh              # daily start/stop helper
├── PROGRESS.md             # phase tracker
├── terraform/
│   ├── main.tf             # full infrastructure
│   ├── variables.tf        # configurable parameters
│   └── outputs.tf          # instance IDs and IPs
├── k8s/
│   ├── elasticsearch.yaml  # ECK Elasticsearch CR
│   ├── kibana.yaml         # ECK Kibana CR
│   └── namespace.yaml      # lab namespace
├── docs/
│   ├── architecture.md     # detailed topology
│   ├── eck-internals.md    # operator pattern deep dive
│   └── runbook.md          # bootstrap + troubleshooting
```

## Author

Vu Pham — Senior Network/Security Engineer
GitHub: github.com/pham0158

---
*Part of a series of AWS infrastructure labs bridging
network engineering expertise with cloud-native patterns.*
