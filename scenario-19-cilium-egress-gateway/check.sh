#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
check_header "Scenario 19: Cilium Egress Gateway"
N1IP=$(node_ip node01)
P() { kubectl get ciliumegressgatewaypolicy billing-egress -o jsonpath="$1" 2>/dev/null; }
agent_on_cp() { kubectl -n kube-system get pod -l k8s-app=cilium --field-selector spec.nodeName=controlplane -o jsonpath='{.items[0].metadata.name}'; }

enabled()  { eq "$(cilium_cfg enable-egress-gateway)" true; }
label()    { eq "$(kubectl get node node01 -o jsonpath='{.metadata.labels.egress-gw}')" true; }
sel()      { P '{.spec.selectors[0].podSelector.matchLabels}' | grep -q '"app":"billing"' && P '{.spec.selectors[0].podSelector.matchLabels}' | grep -q 'payments'; }
dest()     { P '{.spec.destinationCIDRs[*]}' | grep -qw '203.0.113.0/24'; }
gwnode()   { eq "$(P '{.spec.egressGateway.nodeSelector.matchLabels.egress-gw}')" true; }
egressip() { eq "$(P '{.spec.egressGateway.egressIP}')" "$N1IP"; }
bpfmap()   { kubectl -n kube-system exec "$(agent_on_cp)" -c cilium-agent -- cilium-dbg bpf egress list | grep -q '203.0.113.0/24'; }

check "Egress gateway is enabled in cilium-config" enabled
check "Node node01 is labelled egress-gw=true" label
check "Policy selects app=billing in namespace payments" sel
check "Policy destinationCIDRs contains 203.0.113.0/24" dest
check "Policy gateway nodeSelector is egress-gw=true" gwnode
check "Policy egressIP is node01's InternalIP ($N1IP)" egressip
check "The policy reached the eBPF map (cilium-dbg bpf egress list)" bpfmap
finish
