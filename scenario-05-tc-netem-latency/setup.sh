#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
need_cluster
echo "=== Setting up Scenario 05: Find and remove injected latency ==="
ensure_pkg ip iproute2
ensure_pkg ping iputils-ping
n1 'ip netns del ckne-lab 2>/dev/null; ip link del veth-lab0 2>/dev/null
    set -e
    ip netns add ckne-lab
    ip link add veth-lab0 type veth peer name veth-lab1
    ip link set veth-lab1 netns ckne-lab
    ip addr add 10.99.0.1/24 dev veth-lab0
    ip link set veth-lab0 up
    ip netns exec ckne-lab ip addr add 10.99.0.2/24 dev veth-lab1
    ip netns exec ckne-lab ip link set veth-lab1 up
    ip netns exec ckne-lab ip link set lo up
    tc qdisc add dev veth-lab0 root netem delay 300ms'
log "Measured RTT on node01 (expect ~300 ms):"
n1 'ping -c2 -q 10.99.0.2 | tail -1' || true
echo "=== Setup complete. See TASK.md ==="
