#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
echo "=== Cleaning up Scenario 05 ==="
n1 'ip netns del ckne-lab 2>/dev/null; ip link del veth-lab0 2>/dev/null; true' || true
echo "=== Cleanup complete ==="
