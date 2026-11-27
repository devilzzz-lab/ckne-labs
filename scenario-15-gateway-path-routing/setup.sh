#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
need_cluster
echo "=== Setting up Scenario 15: Gateway API path routing ==="
ensure_envoy_gateway
kubectl delete ns web --ignore-not-found --wait=true >/dev/null 2>&1 || true
kubectl create ns web >/dev/null
kubectl -n web apply -f - >/dev/null <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata: {name: frontend}
spec:
  replicas: 1
  selector: {matchLabels: {app: frontend}}
  template:
    metadata: {labels: {app: frontend}}
    spec:
      containers:
      - {name: app, image: "hashicorp/http-echo:1.0", args: ["-listen=:80", "-text=frontend"], ports: [{containerPort: 80}]}
---
apiVersion: v1
kind: Service
metadata: {name: frontend}
spec:
  selector: {app: frontend}
  ports: [{port: 80, targetPort: 80}]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: api}
spec:
  replicas: 1
  selector: {matchLabels: {app: api}}
  template:
    metadata: {labels: {app: api}}
    spec:
      containers:
      - {name: app, image: "hashicorp/http-echo:1.0", args: ["-listen=:8080", "-text=api"], ports: [{containerPort: 8080}]}
---
apiVersion: v1
kind: Service
metadata: {name: api}
spec:
  selector: {app: api}
  ports: [{port: 8080, targetPort: 8080}]
EOF
kubectl -n web rollout status deploy/frontend --timeout=120s >/dev/null
kubectl -n web rollout status deploy/api --timeout=120s >/dev/null
echo "GatewayClass: $(kubectl get gatewayclass eg -o jsonpath='{.status.conditions[?(@.type=="Accepted")].status}')"
echo "=== Setup complete. See TASK.md ==="
