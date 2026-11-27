#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
check_header "Scenario 30: Istio waypoint + L7 policy"
code() { kubectl -n bank exec "$1" -- curl -s -m6 -o /dev/null -w '%{http_code}' "${@:2}" 2>/dev/null; }
# want <pod> <expected-code> <curl args...> (retries: policy and waypoint need a moment)
want() { local pod=$1 exp=$2; shift 2; local i; for i in 1 2 3 4 5 6 7 8; do [ "$(code "$pod" "$@")" = "$exp" ] && return 0; sleep 4; done; return 1; }
AP() { kubectl -n bank get authorizationpolicy ledger-policy -o jsonpath="$1" 2>/dev/null; }

wp_exists() { kubectl -n bank get gateway waypoint; }
wp_ready()  { eq "$(kubectl -n bank get gateway waypoint -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}')" True; }
enrolled()  { eq "$(kubectl get ns bank -o jsonpath='{.metadata.labels.istio\.io/use-waypoint}')" waypoint; }
no_sel()    { [ -z "$(AP '{.spec.selector}')" ]; }
target()    { eq "$(AP '{.spec.targetRefs[0].kind}')" Service && eq "$(AP '{.spec.targetRefs[0].name}')" ledger; }
allow()     { eq "$(AP '{.spec.action}')" ALLOW || [ -z "$(AP '{.spec.action}')" ]; }
t_post()    { want teller 200 -X POST http://ledger/transfer; }
t_get()     { want teller 403 http://ledger/transfer; }
t_admin()   { want teller 403 -X POST http://ledger/admin; }
a_post()    { want auditor 403 -X POST http://ledger/transfer; }

check "A waypoint Gateway exists in bank" wp_exists
check "The waypoint is Programmed" wp_ready
check "Namespace bank uses the waypoint (istio.io/use-waypoint=waypoint)" enrolled
check "ledger-policy no longer uses a Pod selector" no_sel
check "ledger-policy targets Service ledger with targetRefs" target
check "ledger-policy is an ALLOW policy" allow
check "teller: POST /transfer -> 200" t_post
check "teller: GET /transfer -> 403" t_get
check "teller: POST /admin -> 403" t_admin
check "auditor: POST /transfer -> 403" a_post
finish
