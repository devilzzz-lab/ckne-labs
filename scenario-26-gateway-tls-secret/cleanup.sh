#!/usr/bin/env bash
echo "=== Cleaning up Scenario 26 ==="
kubectl delete ns web --ignore-not-found
rm -rf /opt/certs
echo "=== Cleanup complete ==="
