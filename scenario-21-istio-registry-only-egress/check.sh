#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
check_header "Scenario 21: Istio registry-only egress"
code() { kubectl -n egress-lab exec curl-client -c curl -- curl -s -o /dev/null -w '%{http_code}' -m6 "$1" 2>/dev/null; }

sidecar_ok() { eq "$(kubectl -n egress-lab get sidecar default -o jsonpath='{.spec.outboundTrafficPolicy.mode}')" REGISTRY_ONLY; }
se_host()    { kubectl -n egress-lab get serviceentry ext-example -o jsonpath='{.spec.hosts[*]}' | grep -qw example.com; }
se_cfg()     { eq "$(kubectl -n egress-lab get serviceentry ext-example -o jsonpath='{.spec.location}')" MESH_EXTERNAL && eq "$(kubectl -n egress-lab get serviceentry ext-example -o jsonpath='{.spec.resolution}')" DNS && eq "$(kubectl -n egress-lab get serviceentry ext-example -o jsonpath='{.spec.ports[0].number}')" 80; }
allowed()    { retry 10 3 bash -c "[ \"\$(kubectl -n egress-lab exec curl-client -c curl -- curl -s -o /dev/null -w '%{http_code}' -m6 http://example.com 2>/dev/null)\" = 200 ]"; }
blocked()    { retry 10 3 bash -c "[ \"\$(kubectl -n egress-lab exec curl-client -c curl -- curl -s -o /dev/null -w '%{http_code}' -m6 http://example.org 2>/dev/null)\" = 502 ]"; }

check "Sidecar 'default' sets outboundTrafficPolicy REGISTRY_ONLY" sidecar_ok
check "ServiceEntry ext-example registers example.com" se_host
check "ServiceEntry: MESH_EXTERNAL, DNS resolution, port 80" se_cfg
check "http://example.com returns 200 (registered)" allowed
check "http://example.org returns 502 (not registered, blocked)" blocked
finish
