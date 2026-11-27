#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
check_header "Scenario 14: Service with no endpoints"
D() { kubectl -n shop get deploy checkout -o jsonpath="$1" 2>/dev/null; }

sel_ok()   { eq "$(kubectl -n shop get svc checkout -o jsonpath='{.spec.selector.app}')" checkout; }
port_ok()  { eq "$(kubectl -n shop get svc checkout -o jsonpath='{.spec.ports[0].targetPort}')" 8080; }
labels_ok(){ eq "$(D '{.spec.template.metadata.labels.app}')" checkout; }
probe_ok() { eq "$(D '{.spec.template.spec.containers[0].readinessProbe.tcpSocket.port}')" 8080 && eq "$(D '{.spec.template.spec.containers[0].readinessProbe.periodSeconds}')" 5; }
ready2()   { [ "$(kubectl -n shop get endpointslices -l kubernetes.io/service-name=checkout -o jsonpath='{range .items[*].endpoints[*]}{.conditions.ready}{"\n"}{end}' | grep -c true)" -eq 2 ]; }
works()    { retry 10 3 bash -c "[ \"\$(kubectl -n shop exec toolbox -- curl -s -m3 http://checkout:8080)\" = checkout-ok ]"; }

check "Service selector matches the Pods (app=checkout)" sel_ok
check "Service targetPort is 8080" port_ok
check "Pod template labels were not changed" labels_ok
check "Deployment has a tcpSocket readiness probe on 8080, periodSeconds 5" probe_ok
check "Both replicas are ready endpoints" ready2
check "curl http://checkout:8080 returns checkout-ok" works
finish
