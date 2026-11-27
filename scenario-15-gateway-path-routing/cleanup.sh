#!/usr/bin/env bash
echo "=== Cleaning up Scenario 15 ==="
kubectl delete ns web --ignore-not-found
echo "(Envoy Gateway itself is left installed; other Gateway scenarios reuse it.)"
echo "=== Cleanup complete ==="
