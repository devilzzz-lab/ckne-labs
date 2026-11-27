#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
check_header "Scenario 25: WireGuard encryption"
AG=$(kubectl -n kube-system get pod -l k8s-app=cilium --field-selector spec.nodeName=controlplane -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
status() { kubectl -n kube-system exec "$AG" -c cilium-agent -- cilium-dbg status 2>/dev/null; }
PEERS=$(status | grep -E '^Encryption:' | sed -n 's/.*Peers: \([0-9]*\).*/\1/p')
NODES=$(kubectl get nodes --no-headers | wc -l | tr -d ' ')

wg_cfg()   { eq "$(cilium_cfg enable-wireguard)" true; }
node_cfg() { eq "$(cilium_cfg encrypt-node)" true; }
st()       { status | grep -E '^Encryption:' | grep -qi wireguard; }
peers()    { eq "$PEERS" "$((NODES - 1))"; }
answer()   { eq "$(ans wg-peers.txt)" "$PEERS"; }
works()    { retry 5 3 bash -c "[ \"\$(kubectl -n enc exec client -- curl -s -m5 http://server:8080)\" = server-ok ]"; }
dev()      { kubectl -n kube-system exec "$AG" -c cilium-agent -- ip link show cilium_wg0; }

check "cilium-config: enable-wireguard=true" wg_cfg
check "cilium-config: encrypt-node=true (node-to-node)" node_cfg
check "Agent status reports Encryption: Wireguard" st
check "The cilium_wg0 device exists on the controlplane agent" dev
check "Peers = number of other nodes ($((NODES - 1)))" peers
check "/opt/answers/wg-peers.txt matches the agent's peer count ($PEERS)" answer
check "Cross-node traffic still works (client -> server)" works
finish
