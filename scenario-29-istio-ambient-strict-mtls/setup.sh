#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
need_cluster
echo "=== Setting up Scenario 29: Istio ambient STRICT mTLS ==="
ensure_istio_ambient
kubectl delete ns bank outside --ignore-not-found --wait=true >/dev/null 2>&1 || true
kubectl create ns bank >/dev/null
kubectl create ns outside >/dev/null
kubectl -n bank create sa teller >/dev/null
kubectl -n bank apply -f - >/dev/null <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata: {name: ledger}
spec:
  replicas: 1
  selector: {matchLabels: {app: ledger}}
  template:
    metadata: {labels: {app: ledger}}
    spec:
      containers:
      - {name: app, image: "ealen/echo-server:0.9.2", ports: [{containerPort: 80}], env: [{name: PORT, value: "80"}]}
---
apiVersion: v1
kind: Service
metadata: {name: ledger}
spec:
  selector: {app: ledger}
  ports: [{port: 80, targetPort: 80}]
---
apiVersion: v1
kind: Pod
metadata: {name: teller}
spec:
  serviceAccountName: teller
  containers:
  - {name: c, image: "curlimages/curl:8.8.0", command: ["sleep", "infinity"]}
EOF
kubectl -n outside apply -f - >/dev/null <<'EOF'
apiVersion: v1
kind: Pod
metadata: {name: intruder}
spec:
  containers:
  - {name: c, image: "curlimages/curl:8.8.0", command: ["sleep", "infinity"]}
EOF
kubectl -n bank rollout status deploy/ledger --timeout=120s >/dev/null
wait_ready bank pod/teller; wait_ready outside pod/intruder
echo "Before the task, both clients reach ledger (plaintext):"
tbx bank teller curl -s -m5 -o /dev/null -w '  teller   -> %{http_code}\n' http://ledger.bank || true
tbx outside intruder curl -s -m5 -o /dev/null -w '  intruder -> %{http_code}\n' http://ledger.bank || true
echo "=== Setup complete. See TASK.md ==="
