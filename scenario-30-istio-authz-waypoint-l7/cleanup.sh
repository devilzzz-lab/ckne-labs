#!/usr/bin/env bash
echo "=== Cleaning up Scenario 30 ==="
kubectl delete ns bank --ignore-not-found
echo "(Istio stays installed.)"
echo "=== Cleanup complete ==="
