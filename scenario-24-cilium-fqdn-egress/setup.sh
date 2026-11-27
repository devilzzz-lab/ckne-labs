#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
need_cluster
echo "=== Setting up Scenario 24: Cilium FQDN egress ==="
require_cilium
kubectl delete ns fqdn --ignore-not-found --wait=true >/dev/null 2>&1 || true
kubectl create ns fqdn >/dev/null
kubectl -n fqdn apply -f - >/dev/null <<'EOF'
apiVersion: v1
kind: Pod
metadata: {name: client, labels: {app: client}}
spec:
  containers:
  - {name: c, image: "curlimages/curl:8.8.0", command: ["sleep", "infinity"]}
EOF
wait_ready fqdn pod/client
echo "=== Setup complete. See TASK.md ==="
