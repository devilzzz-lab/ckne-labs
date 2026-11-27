#!/usr/bin/env bash
echo "=== Cleaning up Scenario 28 ==="
kubectl delete ns store --ignore-not-found
kubectl delete clusterissuer selfsigned --ignore-not-found
echo "=== Cleanup complete ==="
