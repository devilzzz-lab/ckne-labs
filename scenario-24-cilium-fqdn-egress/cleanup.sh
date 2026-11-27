#!/usr/bin/env bash
echo "=== Cleaning up Scenario 24 ==="
kubectl delete ns fqdn --ignore-not-found
echo "=== Cleanup complete ==="
