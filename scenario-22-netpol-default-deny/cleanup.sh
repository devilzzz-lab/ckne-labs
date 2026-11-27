#!/usr/bin/env bash
echo "=== Cleaning up Scenario 22 ==="
kubectl delete ns lockdown --ignore-not-found
echo "=== Cleanup complete ==="
