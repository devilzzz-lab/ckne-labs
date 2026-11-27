#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
need_cluster

echo "=== Setting up Scenario 01: Install Cilium as a kube-proxy replacement ==="
if [ "$(cni_kind)" = cilium ]; then
  warn "Cilium is already installed. This scenario cannot be repeated on this cluster."
  warn "Restart the Killercoda playground to practise it again."
  exit 0
fi
ensure_cilium_cli
wipe_calico
log "Waiting for nodes to go NotReady (no CNI config left)..."
sleep 15
kubectl get nodes || true
echo
echo "API server (for k8sServiceHost): $(api_server_ip):6443"
echo "=== Setup complete. See TASK.md ==="
