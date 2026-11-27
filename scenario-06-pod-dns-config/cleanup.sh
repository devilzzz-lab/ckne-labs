#!/usr/bin/env bash
echo "=== Cleaning up Scenario 06 ==="
kubectl delete ns conn --ignore-not-found
rm -f /opt/answers/dns-ip.txt
echo "=== Cleanup complete ==="
