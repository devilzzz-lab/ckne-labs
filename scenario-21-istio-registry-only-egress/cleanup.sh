#!/usr/bin/env bash
echo "=== Cleaning up Scenario 21 ==="
kubectl delete ns egress-lab --ignore-not-found
echo "(Istio stays installed; scenarios 29 and 30 reuse it.)"
echo "=== Cleanup complete ==="
