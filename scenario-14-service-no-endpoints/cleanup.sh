#!/usr/bin/env bash
echo "=== Cleaning up Scenario 14 ==="
kubectl delete ns shop --ignore-not-found
echo "=== Cleanup complete ==="
