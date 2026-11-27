#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
need_cluster
echo "=== Setting up Scenario 23: Cilium L7 policy ==="
require_cilium
kubectl delete ns l7 --ignore-not-found --wait=true >/dev/null 2>&1 || true
kubectl create ns l7 >/dev/null
kubectl -n l7 apply -f - >/dev/null <<'EOF'
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
      - {name: app, image: "hashicorp/http-echo:1.0", args: ["-listen=:8080", "-text=api-ok"], ports: [{containerPort: 8080}]}
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
metadata: {name: frontend, labels: {app: frontend}}
spec:
  containers:
  - {name: c, image: "curlimages/curl:8.8.0", command: ["sleep", "infinity"]}
EOF
kubectl -n l7 rollout status deploy/api --timeout=120s >/dev/null
wait_ready l7 pod/frontend
echo "=== Setup complete. See TASK.md ==="
