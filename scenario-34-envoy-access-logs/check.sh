#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
check_header "Scenario 34: Envoy access logs"
UA=$(state_get s34-ua)
IP=$(kubectl -n web get pod client-badlogin -o jsonpath='{.status.podIP}' 2>/dev/null)

ua_ok() { eq "$(ans agent.txt)" "$UA"; }
ip_ok() { eq "$(ans client-ip.txt | sed 's/:[0-9]*$//')" "$IP"; }
logs_ok() { kubectl -n envoy-gateway-system logs -l gateway.envoyproxy.io/owning-gateway-name=web-gw -c envoy --tail=50 | grep -q '/api/login'; }

check "Envoy access logs contain /api/login requests" logs_ok
check "agent.txt = $UA" ua_ok
check "client-ip.txt = $IP" ip_ok
finish
