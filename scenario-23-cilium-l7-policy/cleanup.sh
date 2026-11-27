#!/usr/bin/env bash
echo "=== Cleaning up Scenario 23 ==="
kubectl delete ns l7 --ignore-not-found
echo "=== Cleanup complete ==="
