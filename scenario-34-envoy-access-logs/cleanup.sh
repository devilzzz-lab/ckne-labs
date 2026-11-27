#!/usr/bin/env bash
echo "=== Cleaning up Scenario 34 ==="
kubectl delete ns web --ignore-not-found
rm -f /opt/answers/agent.txt /opt/answers/client-ip.txt
echo "=== Cleanup complete ==="
