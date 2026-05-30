# elasticsearch-k8s-lab Progress

## Phases
- [x] Phase 0 — Project scaffold
- [ ] Phase 1 — Infrastructure + K8s bootstrap
- [ ] Phase 2 — ECK operator install
- [ ] Phase 3 — Elasticsearch deployment
- [ ] Phase 4 — Kibana deployment
- [ ] Phase 5 — Data indexing + search
- [ ] Phase 6 — Self-healing + resilience
- [ ] Phase 7 — Interview prep + GitHub publish

## Current State
Phase: 1A (infrastructure deployed, K8s bootstrap pending)
Last action: terraform apply — 26 resources created, both instances running, K8s 1.29 prereqs installed
Next action: Phase 1B — kubeadm init, Flannel CNI, worker join
AWS resources active: YES — stop with ./cluster.sh stop when done

## Live cluster
Control plane instance: i-030aebd6ce7f3dac7
Worker instance:        i-09fa209372f127e44
Control plane IP:       10.2.1.190 (VPC-A, subnet 10.2.1.0/24)
Worker IP:              10.3.1.61  (VPC-B, subnet 10.3.1.0/24)
Instance type:          c7i-flex.large (2 vCPU, 4 GB RAM)
Note: t3.medium blocked by account SCP — c7i-flex.large is free-tier-eligible on this account, same 4 GB RAM
