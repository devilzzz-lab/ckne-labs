#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
check_header "Scenario 04: Find and remove a rogue iptables rule"
N1IP=$(state_get s04-n1ip); [ -n "$N1IP" ] || N1IP=$(node_ip node01)

works()      { eq "$(curl -s -m5 "http://$N1IP:9090")" "ckne-web-ok"; }
rogue_gone() { ! n1 "iptables -S INPUT | grep -q ckne-maintenance"; }
keep1()      { n1 "iptables -S INPUT | grep -q ckne-legacy-keep"; }
keep2()      { n1 "iptables -S INPUT | grep -q ckne-metrics-keep"; }

check "curl http://node01:9090 works from the controlplane" works
check "The rogue 'maintenance' rule is gone" rogue_gone
check "The other custom rule (tcp 9099) is still in place" keep1
check "The other custom rule (udp 9098) is still in place" keep2
finish
