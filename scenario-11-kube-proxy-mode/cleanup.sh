#!/usr/bin/env bash
echo "=== Cleaning up Scenario 11 ==="
kubectl delete ns px --ignore-not-found
rm -f /opt/answers/proxy-impl.txt /opt/answers/web-clusterip.txt /opt/answers/web-backends.txt
echo "=== Cleanup complete ==="
