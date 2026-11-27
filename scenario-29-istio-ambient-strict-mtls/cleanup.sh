#!/usr/bin/env bash
echo "=== Cleaning up Scenario 29 ==="
kubectl delete ns bank outside --ignore-not-found
echo "(Istio stays installed.)"
echo "=== Cleanup complete ==="
