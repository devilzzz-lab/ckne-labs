#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
echo "=== Cleaning up Scenario 07 ==="
kubectl delete ns net --ignore-not-found
# Remove Multus completely. Its wrapper CNI config must go, or new Pods would fail.
kubectl delete -f "https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/${MULTUS_VERSION}/deployments/multus-daemonset-thick.yml" --ignore-not-found >/dev/null 2>&1 || true
on_all_nodes 'rm -f /etc/cni/net.d/00-multus.conf; rm -rf /etc/cni/net.d/multus.d /run/multus; ip link del br-int 2>/dev/null; true'
echo "=== Cleanup complete ==="
