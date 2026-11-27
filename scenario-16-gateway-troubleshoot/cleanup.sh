#!/usr/bin/env bash
echo "=== Cleaning up Scenario 16 ==="
kubectl delete ns blog --ignore-not-found
echo "=== Cleanup complete ==="
