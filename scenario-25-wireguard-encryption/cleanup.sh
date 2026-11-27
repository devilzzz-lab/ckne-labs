#!/usr/bin/env bash
echo "=== Cleaning up Scenario 25 ==="
kubectl delete ns enc --ignore-not-found
rm -f /opt/answers/wg-peers.txt
echo "(Encryption stays enabled. Restart the playground to reset the CNI.)"
echo "=== Cleanup complete ==="
