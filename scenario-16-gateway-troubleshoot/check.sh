#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
check_header "Scenario 16: Gateway API troubleshooting"
trap gw_forward_stop EXIT
R() { kubectl -n blog get httproute blog -o jsonpath="$1" 2>/dev/null; }

gw_same()  { eq "$(kubectl -n blog get gateway blog-gw -o jsonpath='{.metadata.generation}')" "$(state_get s16-gw-gen)" && eq "$(kubectl -n blog get gateway blog-gw -o jsonpath='{.spec.listeners[0].hostname}')" blog.example.com; }
svc_same() { eq "$(kubectl -n blog get svc blog -o jsonpath='{.spec.ports[0].port}')" "$(state_get s16-svc-port)"; }
accepted() { eq "$(R '{.status.parents[0].conditions[?(@.type=="Accepted")].status}')" True; }
resolved() { eq "$(R '{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}')" True; }
works()    { eq "$(curl -s -m5 -H 'Host: blog.example.com' http://127.0.0.1:18081/)" blog-v1; }

check "Gateway blog-gw was not modified" gw_same
check "Service blog was not modified" svc_same
check "HTTPRoute blog is Accepted by the Gateway" accepted
check "HTTPRoute blog has ResolvedRefs=True" resolved
if gw_forward blog blog-gw 80 18081; then
  check "GET / with Host blog.example.com returns blog-v1" works
else
  check "Envoy proxy for blog-gw is running (port-forward)" false
fi
finish
