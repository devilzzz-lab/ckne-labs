#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
check_header "Scenario 33: Jaeger slow hop"
SLOW=$(state_get s33-slow); ERR=$(state_get s33-err)

jaeger_up() { [ "$(kubectl -n tracing get deploy jaeger -o jsonpath='{.status.readyReplicas}')" = 1 ]; }
gen_ok()    { ! kubectl -n tracing logs deploy/tracegen --tail=5 | grep -q retry; }
slow_ok()   { eq "$(ans slow-service.txt)" "$SLOW"; }
err_ok()    { eq "$(ans error-service.txt)" "$ERR"; }

check "Jaeger is running" jaeger_up
check "The trace generator is sending traces" gen_ok
check "slow-service.txt = $SLOW" slow_ok
check "error-service.txt = $ERR" err_ok
finish
