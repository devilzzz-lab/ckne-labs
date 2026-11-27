#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
need_cluster
echo "=== Setting up Scenario 19: Cilium Egress Gateway ==="
require_cilium
[ "$(cilium_cfg enable-bpf-masquerade)" = true ] || die "The egress gateway needs bpf.masquerade=true (Cilium baseline from scenario 01)."
kubectl delete ciliumegressgatewaypolicies --all >/dev/null 2>&1 || true
kubectl label node node01 egress-gw- >/dev/null 2>&1 || true
kubectl delete ns payments --ignore-not-found --wait=true >/dev/null 2>&1 || true
kubectl create ns payments >/dev/null
kubectl -n payments apply -f - >/dev/null <<'EOF'
apiVersion: v1
kind: Pod
metadata: {name: billing-client, labels: {app: billing}}
spec:
  nodeSelector: {kubernetes.io/hostname: controlplane}
  tolerations: [{operator: Exists}]
  containers:
  - {name: c, image: "curlimages/curl:8.8.0", command: ["sleep", "infinity"]}
EOF
wait_ready payments pod/billing-client
echo "node01 InternalIP (egressIP): $(node_ip node01)"
echo "=== Setup complete. See TASK.md ==="
