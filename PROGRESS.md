# elasticsearch-k8s-lab Progress

## Phases
- [x] Phase 0 — Project scaffold
- [x] Phase 1 — Infrastructure + K8s bootstrap
- [x] Phase 2A — ECK operator installed
- [x] Phase 2B — ECK deep dive
- [x] Phase 3 — Elasticsearch deployment
- [ ] Phase 4 — Kibana deployment
- [ ] Phase 5 — Data indexing + search
- [ ] Phase 6 — Self-healing + resilience
- [ ] Phase 7 — Documentation + GitHub publish

## Current State
Phase: 2B+3 complete
Last action: ECK internals explored, ES deployed green, 3 docs indexed, self-healing verified (pod deleted → recreated in 7s, all data survived)
Next action: Phase 4 — Deploy Kibana
AWS resources active: YES (running ~$0.10/hr)

## Live cluster
Control plane instance: i-030aebd6ce7f3dac7
Worker instance:        i-09fa209372f127e44
Control plane IP:       10.2.1.190 (VPC-A, subnet 10.2.1.0/24)  node name: control-plane
Worker IP:              10.3.1.61  (VPC-B, subnet 10.3.1.0/24)   node name: ip-10-3-1-61.ec2.internal
Instance type:          c7i-flex.large (2 vCPU, 4 GB RAM)
K8s version:            v1.29.15
Pod CIDR:               10.245.0.0/16 (Flannel VXLAN)
Flannel note:           Default manifest uses 10.244.0.0/16 — must patch ConfigMap to 10.245.0.0/16 after apply
