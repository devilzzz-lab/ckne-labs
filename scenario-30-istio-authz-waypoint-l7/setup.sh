#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
need_cluster
echo "=== Setting up Scenario 30: Istio waypoint + L7 policy ==="
ensure_istio_ambient
kubectl delete ns bank --ignore-not-found --wait=true >/dev/null 2>&1 || true
kubectl create ns bank >/dev/null
kubectl label ns bank istio.io/dataplane-mode=ambient >/dev/null
kubectl -n bank create sa teller >/dev/null
kubectl -n bank create sa auditor >/dev/null
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
metadata: {name: ledger, labels: {app: ledger}}
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
---
apiVersion: v1
kind: Pod
metadata: {name: auditor}
spec:
  serviceAccountName: auditor
  containers:
  - {name: c, image: "curlimages/curl:8.8.0", command: ["sleep", "infinity"]}
---
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata: {name: ledger-policy}
spec:
  selector:
    matchLabels: {app: ledger}
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/bank/sa/teller"]
    to:
    - operation:
        methods: ["POST"]
        paths: ["/transfer"]
EOF
kubectl -n bank rollout status deploy/ledger --timeout=120s >/dev/null
wait_ready bank pod/teller; wait_ready bank pod/auditor
echo "=== Setup complete. See TASK.md ==="
