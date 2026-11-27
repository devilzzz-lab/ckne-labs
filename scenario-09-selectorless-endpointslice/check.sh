#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
check_header "Scenario 09: Service without selector + EndpointSlice"
N1IP=$(node_ip node01)
SVC() { kubectl -n ext get svc external-api -o jsonpath="$1" 2>/dev/null; }
ES()  { kubectl -n ext get endpointslice external-api-1 -o jsonpath="$1" 2>/dev/null; }

svc_noselector() { [ -z "$(SVC '{.spec.selector}')" ] && eq "$(SVC '{.spec.ports[0].port}')" 80 && eq "$(SVC '{.spec.ports[0].targetPort}')" 8088 && eq "$(SVC '{.spec.ports[0].name}')" http; }
es_label()   { eq "$(ES '{.metadata.labels.kubernetes\.io/service-name}')" external-api; }
es_addr()    { eq "$(ES '{.endpoints[0].addresses[0]}')" "$N1IP" && eq "$(ES '{.addressType}')" IPv4; }
es_port()    { eq "$(ES '{.ports[0].port}')" 8088 && eq "$(ES '{.ports[0].name}')" http; }
works()      { eq "$(tbx ext toolbox curl -s -m5 http://external-api)" external-api-ok; }

check "Service external-api has no selector, port 80 (http) -> 8088" svc_noselector
check "EndpointSlice external-api-1 carries label kubernetes.io/service-name=external-api" es_label
check "EndpointSlice points at node01's InternalIP ($N1IP), IPv4" es_addr
check "EndpointSlice port is 8088 and named http" es_port
check "curl http://external-api from a Pod returns external-api-ok" works
finish
