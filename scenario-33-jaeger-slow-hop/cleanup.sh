#!/usr/bin/env bash
echo "=== Cleaning up Scenario 33 ==="
kubectl delete ns tracing --ignore-not-found
rm -f /opt/answers/slow-service.txt /opt/answers/error-service.txt
echo "=== Cleanup complete ==="
