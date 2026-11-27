#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
echo "=== Cleaning up Scenario 12 ==="
kubectl delete ns dns-lab --ignore-not-found
coredns_restore
echo "=== Cleanup complete (original Corefile restored) ==="
