#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
need_cluster
echo "=== Setting up Scenario 07: Multi-interface Pod with Multus ==="
[ "$(cni_kind)" = other ] && die "No CNI detected. Install a CNI first."

for p in bridge host-local; do
  [ -x /opt/cni/bin/$p ] || warn "/opt/cni/bin/$p missing on controlplane"
  n1 "[ -x /opt/cni/bin/$p ]" || warn "/opt/cni/bin/$p missing on node01"
done

if ! kubectl -n kube-system get ds kube-multus-ds >/dev/null 2>&1; then
  log "Installing Multus $MULTUS_VERSION (thick plugin)"
  kubectl apply -f "https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/${MULTUS_VERSION}/deployments/multus-daemonset-thick.yml" >/dev/null
fi
kubectl -n kube-system rollout status ds/kube-multus-ds --timeout=240s >/dev/null || die "Multus did not become ready"
kubectl delete ns net --ignore-not-found --wait=true >/dev/null 2>&1 || true
kubectl create ns net >/dev/null
kubectl get crd network-attachment-definitions.k8s.cni.cncf.io >/dev/null
echo "=== Setup complete. See TASK.md ==="
