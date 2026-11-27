#!/usr/bin/env bash
echo "=== Cleaning up Scenario 19 ==="
kubectl delete ciliumegressgatewaypolicies --all --ignore-not-found 2>/dev/null || true
kubectl label node node01 egress-gw- 2>/dev/null || true
kubectl delete ns payments --ignore-not-found
echo "=== Cleanup complete ==="
