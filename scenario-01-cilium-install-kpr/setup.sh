#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
need_cluster

echo "=== Setting up Scenario 01: Install Cilium as a kube-proxy replacement ==="
ensure_cilium_cli
if [ "$(cni_kind)" = cilium ]; then
  warn "The playground already runs Cilium. Removing it so you can install it yourself."
  warn "Current config: kube-proxy-replacement=$(cilium_cfg kube-proxy-replacement) bpf-masquerade=$(cilium_cfg enable-bpf-masquerade)"
  wipe_cilium
else
  wipe_calico
fi
log "Waiting for nodes to go NotReady (no CNI config left)..."
sleep 15
kubectl get nodes || true
echo
echo "API server (for k8sServiceHost): $(api_server_ip):6443"
echo "=== Setup complete. See TASK.md ==="
