# Runbook: Elasticsearch K8s Lab

## Prerequisites

Infrastructure deployed and running (`./cluster.sh start`).
Both instances show `Online` in SSM status.

---

## Phase 1: K8s Bootstrap

### 1. Initialize control plane

```bash
./cluster.sh connect-cp

# On control plane:
sudo kubeadm init \
  --pod-network-cidr=10.245.0.0/16 \
  --apiserver-advertise-address=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
```

Expected output: `Your Kubernetes control-plane has initialized successfully!`

Save the `kubeadm join` command printed at the end — needed for the worker.

```bash
# Set up kubectl for the ec2-user
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### 2. Install Flannel CNI

```bash
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

**IMPORTANT:** The default Flannel manifest uses `10.244.0.0/16` but this lab uses `10.245.0.0/16`.
Patch the ConfigMap immediately after applying, before Flannel pods fully start:

```bash
kubectl patch configmap kube-flannel-cfg -n kube-flannel \
  --type merge \
  -p '{"data":{"net-conf.json":"{\"Network\": \"10.245.0.0/16\", \"EnableNFTables\": false, \"Backend\": {\"Type\": \"vxlan\"}}"}}'

kubectl rollout restart daemonset/kube-flannel-ds -n kube-flannel
```

Verify pods come up:
```bash
kubectl get pods -n kube-flannel
# Expected: kube-flannel-ds-XXXXX   1/1   Running  (one per node)
```

If CoreDNS is stuck in `ContainerCreating`, this patch is the fix. The error in CoreDNS events will read:
`failed to load flannel 'subnet.env' file` — caused by Flannel crashing due to the CIDR mismatch.

### 3. Join worker node

On the worker node (from `./cluster.sh connect-worker`):
```bash
sudo kubeadm join <CONTROL_PLANE_IP>:6443 \
  --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH>
```

Back on control plane — verify:
```bash
kubectl get nodes
# Expected:
# NAME           STATUS   ROLES           AGE   VERSION
# ip-10-2-1-x    Ready    control-plane   5m    v1.29.x
# ip-10-3-1-x    Ready    <none>          2m    v1.29.x
```

**Troubleshooting:** If node shows `NotReady`, check Flannel:
```bash
kubectl describe node <node-name>
kubectl logs -n kube-flannel ds/kube-flannel-ds
```

---

## Phase 2: ECK Operator

### 1. Install CRDs and operator

```bash
kubectl create -f https://download.elastic.co/downloads/eck/2.14.0/crds.yaml
kubectl apply -f https://download.elastic.co/downloads/eck/2.14.0/operator.yaml
```

### 2. Verify operator is running

```bash
kubectl get pods -n elastic-system
# Expected: elastic-operator-0   1/1   Running

kubectl logs -n elastic-system statefulset.apps/elastic-operator | tail -20
```

---

## Phase 3: Deploy Elasticsearch

### 1. Apply namespace and Elasticsearch CR

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/elasticsearch.yaml
```

### 2. Monitor deployment (~3-5 minutes)

```bash
kubectl get elasticsearch
# NAME         HEALTH   NODES   VERSION   PHASE         AGE
# elastic-lab  green    1       8.14.0    Ready         5m

kubectl get pods -l elasticsearch.k8s.elastic.co/cluster-name=elastic-lab
```

**Troubleshooting — pod stuck in Pending:**
```bash
kubectl describe pod <es-pod-name>
# Check Events section for resource or PVC issues
kubectl get pvc
```

If PVC stuck in Pending, check storage class:
```bash
kubectl get storageclass
```

If no storage class exists (bare kubeadm cluster), install local-path-provisioner:
```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.26/deploy/local-path-storage.yaml
kubectl patch storageclass local-path \
  -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```
This uses worker node local disk. Sufficient for single-node lab — no EBS CSI driver needed.

### 3. Get Elasticsearch credentials

ECK auto-generates the `elastic` user password:
```bash
kubectl get secret elastic-lab-es-elastic-user \
  -o jsonpath='{.data.elastic}' | base64 --decode
echo
```

### 4. Verify ES is responding

From inside the cluster, use the ClusterIP or service DNS:
```bash
# Get ClusterIP
kubectl get svc elastic-lab-es-http

# Test via kubectl exec on the ES pod
kubectl exec elastic-lab-es-default-0 -- bash -c \
  'curl -s -u "elastic:PASSWORD" -k https://localhost:9200'
# Expected: {"name":"elastic-lab-es-default-0",...,"tagline":"You Know, for Search"}
```

**Note on SSM terminal line wrapping:** The SSM terminal wraps at ~80 columns.
Long `curl -d` commands with JSON payloads will break. Use Python instead:
```bash
# Write script with short echo lines, run python3 directly
# Use ClusterIP (e.g. 10.96.231.119:9200) from control plane
# ssl.CERT_NONE skips self-signed cert verification
```

### 5. Check cluster health

```bash
kubectl exec elastic-lab-es-default-0 -- bash -c \
  'curl -s -u "elastic:PASSWORD" -k https://localhost:9200/_cluster/health?pretty'
# Expected: "status":"green", "number_of_nodes":1
```

### 6. Self-healing behavior

ECK automatically recreates deleted pods and reattaches the PVC:
```bash
kubectl delete pod elastic-lab-es-default-0
kubectl get pods -l elasticsearch.k8s.elastic.co/cluster-name=elastic-lab --watch
# Pod recreates in ~7s, ready in ~90s
# All data survives — PVC persists independently of the pod
```

---

## Phase 4: Deploy Kibana

```bash
kubectl apply -f k8s/kibana.yaml

kubectl get kibana
# NAME         HEALTH   NODES   VERSION   AGE
# elastic-lab  green    1       8.14.0    3m
```

---

## Getting Elasticsearch Credentials

ECK auto-generates credentials. Retrieve the elastic user password:

```bash
kubectl get secret elastic-lab-es-elastic-user -o jsonpath='{.data.elastic}' | base64 --decode
echo  # newline
```

The CA certificate for TLS:
```bash
kubectl get secret elastic-lab-es-http-certs-public -o jsonpath='{.data.tls\.crt}' | base64 --decode > /tmp/es-ca.crt
```

---

## Verify Cluster Health

### From inside the cluster (on control plane):

```bash
ES_PASSWORD=$(kubectl get secret elastic-lab-es-elastic-user -o jsonpath='{.data.elastic}' | base64 --decode)
ES_IP=$(kubectl get svc elastic-lab-es-http -o jsonpath='{.spec.clusterIP}')

curl -u "elastic:${ES_PASSWORD}" -k "https://${ES_IP}:9200/_cluster/health?pretty"
```

Expected:
```json
{
  "status" : "green",
  "number_of_nodes" : 1,
  "active_shards" : 1
}
```

### Check pod status:

```bash
kubectl get pods
kubectl get elasticsearch
kubectl get kibana
```

---

## Common Troubleshooting

| Symptom | Check | Fix |
|---|---|---|
| Node `NotReady` | `kubectl describe node` | Check Flannel pods, verify VXLAN UDP 8472 in SG |
| ES pod `Pending` | `kubectl describe pod` | Check PVC, node resources (`kubectl top node`) |
| ES pod `CrashLoopBackOff` | `kubectl logs <pod>` | Usually mmap or memory — verify `node.store.allow_mmap: false` |
| Worker can't join | Check `kubeadm join` token expiry | Re-generate: `kubeadm token create --print-join-command` |
| SSM not connecting | Check IAM profile attached | Verify instance profile in EC2 console |
| Kibana not connecting | `kubectl logs <kibana-pod>` | Wait for ES to be fully `green` first |

---

## Daily Workflow

```bash
# Morning — start cluster (takes ~90s for SSM)
./cluster.sh start

# Check everything is up
./cluster.sh status

# Connect and work
./cluster.sh connect-cp

# Evening — stop to save money
./cluster.sh stop
# Cost while stopped: ~$0.003/hr (just EBS)

# Permanent teardown when done
./cluster.sh destroy
```

---

## Useful kubectl Commands

```bash
# Watch all pods in real time
kubectl get pods --all-namespaces -w

# Check resource usage
kubectl top nodes
kubectl top pods

# Get all ECK resources
kubectl get elasticsearch,kibana --all-namespaces

# Tail ECK operator logs
kubectl logs -n elastic-system statefulset/elastic-operator -f

# Port-forward Kibana locally (from your laptop via SSM port forwarding)
kubectl port-forward svc/elastic-lab-kb-http 5601:5601
```
