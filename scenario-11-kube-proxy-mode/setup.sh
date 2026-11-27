#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
need_cluster
echo "=== Setting up Scenario 11: Which proxy programs the Services? ==="
rm -f "$ANS_DIR"/proxy-impl.txt "$ANS_DIR"/web-clusterip.txt "$ANS_DIR"/web-backends.txt
kubectl delete ns px --ignore-not-found --wait=true >/dev/null 2>&1 || true
kubectl create ns px >/dev/null
kubectl -n px apply -f - >/dev/null <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata: {name: web}
spec:
  replicas: 3
  selector: {matchLabels: {app: web}}
  template:
    metadata: {labels: {app: web}}
    spec:
      containers:
      - {name: nginx, image: "nginx:1.27", ports: [{containerPort: 80}]}
---
apiVersion: v1
kind: Service
metadata: {name: web}
spec:
  selector: {app: web}
  ports: [{port: 80, targetPort: 80}]
EOF
kubectl -n px rollout status deploy/web --timeout=120s >/dev/null
echo "=== Setup complete. See TASK.md ==="
