#!/usr/bin/env bash
# Shortcut for "session B": replace Calico + kube-proxy with the Cilium baseline.
# This is exactly what scenario 01 asks YOU to do by hand. Use this to skip it.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
need_cluster

if [ "$(cni_kind)" = cilium ]; then
  log "Cilium is already installed."; exit 0
fi
echo "This replaces the cluster CNI (Calico → Cilium) and removes kube-proxy."
echo "Use a throwaway playground. Restart the playground to get Calico back."
read -r -p "Continue? [y/N] " a; [ "${a:-n}" = y ] || exit 0

ensure_cilium_cli
wipe_calico
sleep 5
cilium_baseline_install
kubectl get nodes
