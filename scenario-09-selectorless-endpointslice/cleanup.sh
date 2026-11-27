#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
echo "=== Cleaning up Scenario 09 ==="
kubectl delete ns ext --ignore-not-found
n1 'systemctl stop ckne-ext 2>/dev/null; systemctl reset-failed ckne-ext 2>/dev/null; rm -rf /srv/ckne-ext; true' || true
echo "=== Cleanup complete ==="
