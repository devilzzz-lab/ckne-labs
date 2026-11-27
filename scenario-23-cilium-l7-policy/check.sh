#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
check_header "Scenario 23: Cilium L7 policy"
code() { kubectl -n l7 exec frontend -- curl -s -o /dev/null -w '%{http_code}' -m5 "$@" 2>/dev/null; }
C() { kubectl -n l7 get cnp api-l7 -o jsonpath="$1" 2>/dev/null; }

exists()  { kubectl -n l7 get cnp api-l7; }
sel()     { eq "$(C '{.spec.endpointSelector.matchLabels.app}')" api; }
http()    { [ -n "$(C '{.spec.ingress[0].toPorts[0].rules.http[0].path}')" ]; }
get_ok()  { retry 6 3 bash -c "[ \"\$(kubectl -n l7 exec frontend -- curl -s -o /dev/null -w '%{http_code}' -m5 http://api:8080/products 2>/dev/null)\" = 200 ]"; }
sub_ok()  { eq "$(code http://api:8080/products/42)" 200; }
admin()   { eq "$(code http://api:8080/admin)" 403; }
post()    { eq "$(code -X POST http://api:8080/products)" 403; }
other()   { eq "$(code http://api:8080/productsx)" 403; }

check "CiliumNetworkPolicy api-l7 exists" exists
check "It selects Pods app=api" sel
check "It has an L7 http rule" http
check "GET /products returns 200" get_ok
check "GET /products/42 returns 200" sub_ok
check "GET /admin returns 403" admin
check "POST /products returns 403" post
check "GET /productsx returns 403 (path regex is not too loose)" other
finish
