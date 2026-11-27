#!/usr/bin/env bash
echo "=== Cleaning up Scenario 31 ==="
kubectl delete ns finance --ignore-not-found
rm -f /opt/answers/dropped-source.txt /opt/answers/drop-reason.txt
echo "(Hubble stays enabled.)"
echo "=== Cleanup complete ==="
