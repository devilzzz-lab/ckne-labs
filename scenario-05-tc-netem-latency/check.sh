#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
check_header "Scenario 05: Find and remove injected latency"

no_netem()  { ! n1 "tc qdisc show dev veth-lab0 | grep -q netem"; }
veth_ok()   { n1 "ip link show veth-lab0 >/dev/null && ip netns exec ckne-lab ip link show veth-lab1 >/dev/null"; }
fast()      { local rtt; rtt=$(n1 "ping -c3 -q 10.99.0.2 | awk -F/ '/^rtt/{print \$5}'"); [ -n "$rtt" ] && awk -v r="$rtt" 'BEGIN{exit !(r<50)}'; }

check "No netem qdisc on veth-lab0" no_netem
check "veth-lab0, the ckne-lab namespace and veth-lab1 still exist" veth_ok
check "Average RTT to 10.99.0.2 is below 50 ms" fast
finish
