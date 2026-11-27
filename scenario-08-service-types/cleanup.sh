#!/usr/bin/env bash
echo "=== Cleaning up Scenario 08 ==="
kubectl delete ns svc-lab --ignore-not-found
echo "=== Cleanup complete ==="
