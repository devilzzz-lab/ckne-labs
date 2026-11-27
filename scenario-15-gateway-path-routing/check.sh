#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
check_header "Scenario 15: Gateway API path routing"
trap gw_forward_stop EXIT
G() { kubectl -n web get gateway web-gw -o jsonpath="$1" 2>/dev/null; }
R() { kubectl -n web get httproute shop -o jsonpath="$1" 2>/dev/null; }

gw_cfg()   { eq "$(G '{.spec.gatewayClassName}')" eg && eq "$(G '{.spec.listeners[0].name}')" http && eq "$(G '{.spec.listeners[0].port}')" 80 && eq "$(G '{.spec.listeners[0].protocol}')" HTTP && eq "$(G '{.spec.listeners[0].hostname}')" shop.example.com; }
gw_acc()   { eq "$(G '{.status.conditions[?(@.type=="Accepted")].status}')" True; }
rt_acc()   { eq "$(R '{.status.parents[0].conditions[?(@.type=="Accepted")].status}')" True && eq "$(R '{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}')" True; }
rt_cfg()   { eq "$(R '{.spec.hostnames[0]}')" shop.example.com && R '{.spec.rules[*].backendRefs[*].name}' | grep -qw api && R '{.spec.rules[*].backendRefs[*].name}' | grep -qw frontend; }
req()      { curl -s -m5 -H 'Host: shop.example.com' "http://127.0.0.1:18080$1"; }
api_ok()   { eq "$(req /api)" api && eq "$(req /api/v1/users)" api; }
fe_ok()    { eq "$(req /)" frontend && eq "$(req /other)" frontend; }
host_ok()  { [ "$(curl -s -m5 -o /dev/null -w '%{http_code}' -H 'Host: other.example.com' http://127.0.0.1:18080/)" = 404 ]; }

check "Gateway web-gw: class eg, listener http/80/HTTP, hostname shop.example.com" gw_cfg
check "Gateway is Accepted" gw_acc
check "HTTPRoute shop is Accepted and its refs are resolved" rt_acc
check "HTTPRoute uses hostname shop.example.com with backends api and frontend" rt_cfg
if gw_forward web web-gw 80 18080; then
  check "GET /api and /api/... return 'api'" api_ok
  check "GET / and /other return 'frontend'" fe_ok
  check "An unknown hostname gets 404" host_ok
else
  check "Envoy proxy for web-gw is running (port-forward)" false
fi
finish
