#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
need_cluster
echo "=== Setting up Scenario 06: Fix a Pod that cannot resolve cluster DNS ==="
rm -f "$ANS_DIR/dns-ip.txt"
kubectl delete ns conn --ignore-not-found --wait=true >/dev/null 2>&1 || true
kubectl create ns conn >/dev/null
kubectl -n conn apply -f - >/dev/null <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata: {name: server}
spec:
  replicas: 2
  selector: {matchLabels: {app: server}}
  template:
    metadata: {labels: {app: server}}
    spec:
      containers:
      - {name: nginx, image: "nginx:1.27", ports: [{containerPort: 80}]}
---
apiVersion: v1
kind: Service
metadata: {name: server}
spec:
  selector: {app: server}
  ports: [{port: 80, targetPort: 80}]
---
apiVersion: v1
kind: Pod
metadata: {name: client}
spec:
  dnsPolicy: "None"
  dnsConfig:
    nameservers: ["8.8.8.8"]
    searches: ["example.local"]
  containers:
  - name: c
    image: curlimages/curl:8.8.0
    command: ["sleep", "infinity"]
EOF
kubectl -n conn rollout status deploy/server --timeout=120s >/dev/null
wait_ready conn pod/client
echo "=== Setup complete. See TASK.md ==="
