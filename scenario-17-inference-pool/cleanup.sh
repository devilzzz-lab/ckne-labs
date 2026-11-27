#!/usr/bin/env bash
echo "=== Cleaning up Scenario 17 ==="
kubectl delete ns inference --ignore-not-found
echo "(Inference CRDs are left installed.)"
echo "=== Cleanup complete ==="
