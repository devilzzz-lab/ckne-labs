#!/usr/bin/env bash
echo "=== Cleaning up Scenario 20 ==="
kubectl delete ns shop --ignore-not-found
rm -rf /root/clustermesh
rm -f /opt/answers/ca-copy.txt
echo "=== Cleanup complete ==="
