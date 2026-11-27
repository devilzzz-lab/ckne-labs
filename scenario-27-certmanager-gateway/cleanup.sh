#!/usr/bin/env bash
echo "=== Cleaning up Scenario 27 ==="
kubectl delete ns secure --ignore-not-found
kubectl delete clusterissuer selfsigned --ignore-not-found
echo "(cert-manager stays installed; scenario 28 reuses it.)"
echo "=== Cleanup complete ==="
