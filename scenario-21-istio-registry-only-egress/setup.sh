#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
need_cluster
echo "=== Setting up Scenario 21: Istio registry-only egress ==="
ensure_istio_ambient
kubectl delete ns egress-lab --ignore-not-found --wait=true >/dev/null 2>&1 || true
kubectl create ns egress-lab >/dev/null
kubectl label ns egress-lab istio-injection=enabled >/dev/null
kubectl -n egress-lab apply -f - >/dev/null <<'EOF'
apiVersion: v1
kind: Pod
metadata: {name: curl-client}
spec:
  containers:
  - {name: curl, image: "curlimages/curl:8.8.0", command: ["sleep", "infinity"]}
EOF
wait_ready egress-lab pod/curl-client 240s
echo "Containers in curl-client: $(kubectl -n egress-lab get pod curl-client -o jsonpath='{.spec.containers[*].name}')"
echo "=== Setup complete. See TASK.md ==="
