#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
check_header "Scenario 32: Prometheus failing backend"
BAD=$(state_get s32-bad)

bad_ok()    { eq "$(ans bad-pod.txt)" "$BAD"; }
q_rate()    { grep -q 'rate(' "$ANS_DIR/query.txt" && grep -q 'app_http_requests_total' "$ANS_DIR/query.txt"; }
# The saved query must actually run against Prometheus and return at least one series.
q_runs() {
  kubectl -n obs port-forward svc/prometheus 19090:9090 >/dev/null 2>&1 & local pf=$!
  sleep 3
  local out; out=$(curl -s -m10 'http://127.0.0.1:19090/api/v1/query' --data-urlencode "query=$(head -n1 "$ANS_DIR/query.txt")")
  kill $pf 2>/dev/null
  echo "$out" | grep -q '"status":"success"' && ! echo "$out" | grep -q '"result":\[\]'
}
prom_up()   { [ "$(kubectl -n obs get deploy prometheus -o jsonpath='{.status.readyReplicas}')" = 1 ]; }

check "Prometheus is running" prom_up
check "bad-pod.txt = $BAD" bad_ok
check "query.txt uses rate( and app_http_requests_total" q_rate
check "The saved query runs in Prometheus and returns data" q_runs
finish
