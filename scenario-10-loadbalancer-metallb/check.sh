#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
check_header "Scenario 10: MetalLB"
POOL() { kubectl -n metallb-system get ipaddresspool lab-pool -o jsonpath="$1" 2>/dev/null; }
LB()   { kubectl -n lb-lab get svc shop-lb -o jsonpath="$1" 2>/dev/null; }

pool_ok() { eq "$POOL_ADDR" "172.30.255.200-172.30.255.220"; }
l2_ok()   { kubectl -n metallb-system get l2advertisement lab-l2 -o jsonpath='{.spec.ipAddressPools[*]}' | grep -qw lab-pool; }
svc_ok()  { eq "$(LB '{.spec.type}')" LoadBalancer && eq "$(LB '{.spec.ports[0].port}')" 80 && eq "$(LB '{.spec.selector.app}')" shop-web; }
ip_ok()   { local ip last; ip=$(LB '{.status.loadBalancer.ingress[0].ip}'); last=${ip##*.}; [[ "$ip" == 172.30.255.* ]] && [ "$last" -ge 200 ] && [ "$last" -le 220 ]; }

POOL_ADDR=$(POOL '{.spec.addresses[0]}')
check "IPAddressPool lab-pool has 172.30.255.200-172.30.255.220" pool_ok
check "L2Advertisement lab-l2 advertises lab-pool" l2_ok
check "Service shop-lb is a LoadBalancer on port 80 selecting app=shop-web" svc_ok
check "shop-lb received an external IP from the pool" ip_ok
finish
