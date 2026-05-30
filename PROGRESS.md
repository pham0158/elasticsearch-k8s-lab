# elasticsearch-k8s-lab Progress

## Phases
- [x] Phase 0 — Project scaffold
- [x] Phase 1 — Infrastructure + K8s bootstrap
- [ ] Phase 2 — ECK operator install
- [ ] Phase 3 — Elasticsearch deployment
- [ ] Phase 4 — Kibana deployment
- [ ] Phase 5 — Data indexing + search
- [ ] Phase 6 — Self-healing + resilience
- [ ] Phase 7 — Documentation + GitHub publish

## Current State
Phase: 1 complete
Last action: K8s bootstrapped — both nodes Ready, control-plane VPC-A (10.2.1.190), worker VPC-B (10.3.1.61)
Next action: Phase 2 — ECK operator install
AWS resources active: YES — stop with ./cluster.sh stop when done (~$0.10/hr while running)

## Live cluster
Control plane instance: i-030aebd6ce7f3dac7
Worker instance:        i-09fa209372f127e44
Control plane IP:       10.2.1.190 (VPC-A, subnet 10.2.1.0/24)  node name: control-plane
Worker IP:              10.3.1.61  (VPC-B, subnet 10.3.1.0/24)   node name: ip-10-3-1-61.ec2.internal
Instance type:          c7i-flex.large (2 vCPU, 4 GB RAM)
K8s version:            v1.29.15
Pod CIDR:               10.245.0.0/16 (Flannel VXLAN)
Flannel note:           Default manifest uses 10.244.0.0/16 — must patch ConfigMap to 10.245.0.0/16 after apply
