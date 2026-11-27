#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
check_header "Scenario 18: Cilium BGP Control Plane"
FRR=$(kubectl -n bgp-lab get pod frr-router -o jsonpath='{.status.podIP}')
CC() { kubectl get ciliumbgpclusterconfig cilium-bgp -o jsonpath="$1" 2>/dev/null; }
PC() { kubectl get ciliumbgppeerconfig frr-peer -o jsonpath="$1" 2>/dev/null; }
AD() { kubectl get ciliumbgpadvertisement bgp-adv -o jsonpath="$1" 2>/dev/null; }

enabled()    { eq "$(cilium_cfg enable-bgp-control-plane)" true; }
node_label() { eq "$(kubectl get node controlplane -o jsonpath='{.metadata.labels.bgp}')" enabled; }
cc_sel()     { eq "$(CC '{.spec.nodeSelector.matchLabels.bgp}')" enabled; }
cc_asn()     { eq "$(CC '{.spec.bgpInstances[0].localASN}')" 65001; }
cc_peer()    { eq "$(CC '{.spec.bgpInstances[0].peers[0].peerASN}')" 65000 && eq "$(CC '{.spec.bgpInstances[0].peers[0].peerAddress}')" "$FRR"; }
cc_ref()     { eq "$(CC '{.spec.bgpInstances[0].peers[0].peerConfigRef.name}')" frr-peer && kubectl get ciliumbgppeerconfig frr-peer; }
pc_fam()     { eq "$(PC '{.spec.families[0].afi}')" ipv4 && eq "$(PC '{.spec.families[0].safi}')" unicast; }
pc_sel()     { eq "$(PC '{.spec.families[0].advertisements.matchLabels.advertise}')" bgp; }
ad_label()   { eq "$(kubectl get ciliumbgpadvertisement bgp-adv -o jsonpath='{.metadata.labels.advertise}')" bgp; }
ad_types()   { AD '{.spec.advertisements[*].advertisementType}' | grep -qw PodCIDR && AD '{.spec.advertisements[*].advertisementType}' | grep -qw Service; }
ad_lb()      { AD '{.spec.advertisements[*].service.addresses[*]}' | grep -qw LoadBalancerIP; }
ad_all()     { [ -n "$(AD '{.spec.advertisements[?(@.advertisementType=="Service")].selector}')" ]; }

check "BGP control plane is enabled in cilium-config" enabled
check "Node controlplane is labelled bgp=enabled" node_label
check "ClusterConfig cilium-bgp selects nodes with bgp=enabled" cc_sel
check "BGP instance localASN is 65001" cc_asn
check "Peer: ASN 65000, address = frr-router Pod IP ($FRR)" cc_peer
check "Peer references an existing PeerConfig frr-peer" cc_ref
check "PeerConfig: ipv4 unicast family" pc_fam
check "PeerConfig selects advertisements with label advertise=bgp" pc_sel
check "Advertisement bgp-adv carries the label advertise=bgp" ad_label
check "Advertisement announces PodCIDR and Service" ad_types
check "Service advertisement uses LoadBalancerIP addresses" ad_lb
check "Service advertisement has a selector (matches all Services)" ad_all

echo
echo "Info: BGP session state (not scored):"
cilium bgp peers 2>/dev/null || echo "  (cilium bgp peers is not available yet)"
finish
