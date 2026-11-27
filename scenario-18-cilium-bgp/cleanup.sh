#!/usr/bin/env bash
echo "=== Cleaning up Scenario 18 ==="
kubectl delete ciliumbgpclusterconfigs,ciliumbgppeerconfigs,ciliumbgpadvertisements --all --ignore-not-found 2>/dev/null || true
kubectl label node controlplane bgp- 2>/dev/null || true
kubectl delete ns bgp-lab --ignore-not-found
echo "(bgpControlPlane.enabled stays on, which is harmless.)"
echo "=== Cleanup complete ==="
