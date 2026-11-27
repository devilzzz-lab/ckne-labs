#!/usr/bin/env bash
# Shortcut for the "Cilium playground": replace the CNI + kube-proxy with the Cilium baseline (KPR + BPF masquerade).
# This is exactly what scenario 01 asks YOU to do by hand. Use this to skip it.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
need_cluster

if [ "$(cni_kind)" = cilium ] && [ "$(cilium_cfg kube-proxy-replacement)" = true ] && [ "$(cilium_cfg enable-bpf-masquerade)" = true ]; then
  log "Cilium is already installed with kube-proxy replacement and BPF masquerading. Nothing to do."; exit 0
fi
echo "This replaces the cluster CNI with the Cilium baseline (KPR + BPF masquerade) and removes kube-proxy."
echo "Use a throwaway playground. Restart the playground to get the original CNI back."
read -r -p "Continue? [y/N] " a; [ "${a:-n}" = y ] || exit 0

ensure_cilium_cli
if [ "$(cni_kind)" = cilium ]; then wipe_cilium; else wipe_calico; fi
sleep 5
cilium_baseline_install
kubectl get nodes
