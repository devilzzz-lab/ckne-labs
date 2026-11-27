#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
need_cluster
echo "=== Setting up Scenario 14: Service with no endpoints ==="
kubectl delete ns shop --ignore-not-found --wait=true >/dev/null 2>&1 || true
kubectl create ns shop >/dev/null
kubectl -n shop apply -f - >/dev/null <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata: {name: checkout}
spec:
  replicas: 2
  selector: {matchLabels: {app: checkout}}
  template:
    metadata: {labels: {app: checkout}}
    spec:
      containers:
      - name: app
        image: hashicorp/http-echo:1.0
        args: ["-listen=:8080", "-text=checkout-ok"]
        ports: [{containerPort: 8080}]
---
apiVersion: v1
kind: Service
metadata: {name: checkout}
spec:
  selector: {app: checkouts}
  ports: [{port: 8080, targetPort: 80}]
EOF
ensure_toolbox shop
kubectl -n shop rollout status deploy/checkout --timeout=120s >/dev/null
wait_ready shop pod/toolbox
echo "=== Setup complete. See TASK.md ==="
