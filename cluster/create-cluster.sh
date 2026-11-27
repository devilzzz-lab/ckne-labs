#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

echo "Verifying the Killercoda cluster is ready for the CKNE labs..."
need_cluster
echo
kubectl get nodes -o wide

COUNT=$(kubectl get nodes --no-headers | wc -l | tr -d ' ')
[ "$COUNT" -ge 2 ] || warn "Only $COUNT node(s) found. Expected controlplane + node01. Several scenarios use node01."

echo
if n1 true 2>/dev/null; then log "ssh node01 works"; else warn "ssh node01 does not work. Scenarios 03, 04, 05 need it."; fi
command -v helm >/dev/null && log "helm present" || warn "helm missing (it is installed on demand)"

echo
case "$(cni_kind)" in
  cilium)
    if [ "$(cilium_cfg kube-proxy-replacement)" = true ] && [ "$(cilium_cfg enable-bpf-masquerade)" = true ]; then
      log "CNI: Cilium with KPR + BPF masquerade. Cilium labs are ready. Istio labs (21, 29, 30) need a fresh playground."
    else
      log "CNI: Cilium (kube-proxy-replacement=$(cilium_cfg kube-proxy-replacement), bpf-masquerade=$(cilium_cfg enable-bpf-masquerade))."
      log "Istio labs (21, 29, 30) run here (they adjust Cilium for you). Cilium labs need lab 01 first."
    fi ;;
  calico) log "CNI: Calico. Istio labs run here. Cilium labs need lab 01 first (it replaces the CNI)." ;;
  *)      warn "No known CNI detected." ;;
esac

mkdir -p "$ANS_DIR" && log "Answer directory: $ANS_DIR"

cat <<EOF

═══════════════════════════════════════════════════
  Cluster ready. Run ./ckne.sh to start studying
═══════════════════════════════════════════════════
  [any playground]    works on a fresh playground
  [Cilium playground] needs Cilium with KPR + BPF masquerade: do lab 01 (or ./cluster/install-cilium.sh)
  [Istio playground]  needs NO Cilium BPF masquerade: use a fresh playground
  After lab 01, restart the playground before the Istio labs.
EOF
