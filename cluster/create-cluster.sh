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
  cilium) log "CNI: Cilium (session B). bpf.masquerade=$(cilium_cfg enable-bpf-masquerade). Istio ambient scenarios (21, 29, 30) will refuse to run." ;;
  calico) log "CNI: Calico (session A). Cilium scenarios (01, 02, 18, 19, 23, 24, 25, 31) need session B." ;;
  *)      warn "No known CNI detected." ;;
esac

mkdir -p "$ANS_DIR" && log "Answer directory: $ANS_DIR"

cat <<EOF

═══════════════════════════════════════════════════
  Cluster ready. Run ./ckne.sh to start studying
═══════════════════════════════════════════════════
  Session A = default Killercoda playground (Calico)
  Session B = Cilium (do scenario 01, or ./cluster/install-cilium.sh)
  Switching between A and B = restart the Killercoda playground.
EOF
