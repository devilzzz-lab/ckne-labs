#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
need_cluster
echo "=== Setting up Scenario 08: Service types ==="
kubectl delete ns svc-lab --ignore-not-found --wait=true >/dev/null 2>&1 || true
kubectl create ns svc-lab >/dev/null
kubectl -n svc-lab apply -f - >/dev/null <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata: {name: web}
spec:
  replicas: 2
  selector: {matchLabels: {app: web}}
  template:
    metadata: {labels: {app: web}}
    spec:
      containers:
      - {name: nginx, image: "nginx:1.27", ports: [{containerPort: 80}]}
EOF
ensure_toolbox svc-lab
kubectl -n svc-lab rollout status deploy/web --timeout=120s >/dev/null
wait_ready svc-lab pod/toolbox
echo "=== Setup complete. See TASK.md ==="
