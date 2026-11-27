#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
need_cluster
echo "=== Setting up Scenario 03: Capture packets with tcpdump ==="
ensure_pkg tcpdump
n1 'mkdir -p /opt/captures && rm -f /opt/captures/api.pcap'

kubectl create ns shop --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n shop apply -f - >/dev/null <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata: {name: api}
spec:
  replicas: 1
  selector: {matchLabels: {app: api}}
  template:
    metadata: {labels: {app: api}}
    spec:
      nodeSelector: {kubernetes.io/hostname: node01}
      containers:
      - name: api
        image: hashicorp/http-echo:1.0
        args: ["-listen=:8080", "-text=api-ok"]
        ports: [{containerPort: 8080}]
---
apiVersion: v1
kind: Service
metadata: {name: api}
spec:
  selector: {app: api}
  ports: [{port: 8080, targetPort: 8080}]
---
apiVersion: v1
kind: Pod
metadata: {name: client, labels: {app: client}}
spec:
  tolerations: [{operator: Exists}]
  nodeSelector: {kubernetes.io/hostname: controlplane}
  containers:
  - name: c
    image: curlimages/curl:8.8.0
    command: ["sh", "-c", "while true; do curl -s -m2 http://api:8080 >/dev/null; sleep 0.5; done"]
EOF
kubectl -n shop rollout status deploy/api --timeout=120s >/dev/null
wait_ready shop pod/client || warn "client pod not ready yet (is the controlplane node named 'controlplane'?)"
kubectl -n shop get pods -o wide
echo "=== Setup complete. See TASK.md ==="
