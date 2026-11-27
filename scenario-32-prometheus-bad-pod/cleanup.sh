#!/usr/bin/env bash
echo "=== Cleaning up Scenario 32 ==="
kubectl delete ns obs --ignore-not-found
rm -f /opt/answers/bad-pod.txt /opt/answers/query.txt
echo "=== Cleanup complete ==="
