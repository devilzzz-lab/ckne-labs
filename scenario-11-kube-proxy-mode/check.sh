#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
check_header "Scenario 11: Which proxy programs the Services?"

if kubectl -n kube-system get ds kube-proxy >/dev/null 2>&1; then
  mode=$(kubectl -n kube-system get cm kube-proxy -o jsonpath='{.data.config\.conf}' | awk '/^mode:/{gsub(/"/,"",$2); print $2}')
  [ -z "$mode" ] && mode=iptables
  impl=$mode
else
  impl=cilium
fi
cip=$(kubectl -n px get svc web -o jsonpath='{.spec.clusterIP}')
exp_backends=$(kubectl -n px get endpointslices -l kubernetes.io/service-name=web -o jsonpath='{range .items[*].endpoints[*]}{.addresses[0]}{"\n"}{end}' | sed 's/$/:80/' | sort)
got_backends=$(grep -v '^[[:space:]]*$' "$ANS_DIR/web-backends.txt" 2>/dev/null | sed 's/[[:space:]]//g' | sort)

check "proxy-impl.txt = $impl" eq "$(ans proxy-impl.txt)" "$impl"
check "web-clusterip.txt = $cip" eq "$(ans web-clusterip.txt)" "$cip"
check "web-backends.txt lists the 3 Pod IP:80 backends" eq "$got_backends" "$exp_backends"
finish
