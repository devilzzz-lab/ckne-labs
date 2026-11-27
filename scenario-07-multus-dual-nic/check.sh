#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
check_header "Scenario 07: Multi-interface Pod with Multus"
NADCFG() { kubectl -n net get net-attach-def internal-net -o jsonpath='{.spec.config}' 2>/dev/null; }

nad_exists() { kubectl -n net get net-attach-def internal-net; }
nad_bridge() { NADCFG | grep -Eq '"type"[[:space:]]*:[[:space:]]*"bridge"'; }
nad_name()   { NADCFG | grep -Eq '"bridge"[[:space:]]*:[[:space:]]*"br-int"'; }
nad_ipam()   { NADCFG | grep -q 'host-local' && NADCFG | grep -q '192.168.50.0/24'; }
pod_running(){ eq "$(kubectl -n net get pod dual-nic -o jsonpath='{.status.phase}')" Running; }
pod_attach() { kubectl -n net get pod dual-nic -o jsonpath='{.metadata.annotations.k8s\.v1\.cni\.cncf\.io/networks}' | grep -q 'internal-net'; }
has_net1()   { tbx net dual-nic ip -4 -o addr show net1 | grep -q '192\.168\.50\.'; }
has_eth0()   { tbx net dual-nic ip -4 -o addr show eth0 | grep -q 'inet '; }
in_range()   { local ip; ip=$(tbx net dual-nic ip -4 -o addr show net1 | awk '{print $4}' | cut -d/ -f1 | awk -F. '{print $4}'); [ "$ip" -ge 100 ] && [ "$ip" -le 150 ]; }

check "NetworkAttachmentDefinition internal-net exists in ns net" nad_exists
check "NAD uses the bridge plugin" nad_bridge
check "NAD bridge is named br-int" nad_name
check "NAD uses host-local IPAM for 192.168.50.0/24" nad_ipam
check "Pod dual-nic is Running" pod_running
check "Pod dual-nic requests the internal-net attachment" pod_attach
check "Pod has eth0 (primary network)" has_eth0
check "Pod has net1 with an address in 192.168.50.0/24" has_net1
check "net1 address is inside .100-.150" in_range
finish
