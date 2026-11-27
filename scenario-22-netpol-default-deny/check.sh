#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
check_header "Scenario 22: NetworkPolicy default deny"
NP() { kubectl -n lockdown get netpol "$1" -o jsonpath="$2" 2>/dev/null; }

deny_ok()   { eq "$(NP default-deny '{.spec.podSelector}')" '{}' && NP default-deny '{.spec.policyTypes[*]}' | grep -qw Ingress && NP default-deny '{.spec.policyTypes[*]}' | grep -qw Egress && [ -z "$(NP default-deny '{.spec.ingress}{.spec.egress}')" ]; }
dns_ok()    { NP allow-dns '{.spec.egress[*].ports[*].port}' | grep -q 53 && NP allow-dns '{.spec.egress[*].ports[*].protocol}' | grep -q UDP && NP allow-dns '{.spec.egress[*].ports[*].protocol}' | grep -q TCP; }
dns_target(){ NP allow-dns '{.spec.egress[*].to[*].podSelector.matchLabels.k8s-app}' | grep -qw kube-dns; }
ingress_ok(){ eq "$(NP api-ingress '{.spec.podSelector.matchLabels.app}')" api && NP api-ingress '{.spec.ingress[*].ports[*].port}' | grep -q 8080; }
egress_ok() { eq "$(NP frontend-egress '{.spec.podSelector.matchLabels.app}')" frontend && NP frontend-egress '{.spec.egress[*].ports[*].port}' | grep -q 8080; }
fe_api()    { retry 5 3 bash -c "[ \"\$(kubectl -n lockdown exec frontend -- curl -s -m4 http://api:8080)\" = api-ok ]"; }
other_blk() { ! kubectl -n lockdown exec other -- curl -s -m4 http://api:8080 | grep -q api-ok; }
fe_ext()    { ! kubectl -n lockdown exec frontend -- curl -s -m4 -o /dev/null http://1.1.1.1; }
dns_all()   { kubectl -n lockdown exec other -- nslookup api.lockdown.svc.cluster.local | grep -q 'Address'; }

check "default-deny: podSelector {} with Ingress and Egress, no rules" deny_ok
check "allow-dns: egress on UDP and TCP 53" dns_ok
check "allow-dns: only to the kube-dns Pods (podSelector k8s-app=kube-dns)" dns_target
check "api-ingress: selects app=api, allows TCP 8080" ingress_ok
check "frontend-egress: selects app=frontend, allows TCP 8080" egress_ok
check "frontend can reach api:8080 (api-ok)" fe_api
check "other cannot reach api:8080" other_blk
check "frontend cannot reach the internet (1.1.1.1)" fe_ext
check "DNS still works for every Pod (other resolves api)" dns_all
finish
