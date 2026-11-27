#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
echo "=== Cleaning up Scenario 03 ==="
kubectl delete ns shop --ignore-not-found
n1 'rm -rf /opt/captures' || true
echo "=== Cleanup complete ==="
