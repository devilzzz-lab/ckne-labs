#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
check_header "Scenario 24: Cilium FQDN egress"
C() { kubectl -n fqdn get cnp client-egress -o jsonpath="$1" 2>/dev/null; }
code() { kubectl -n fqdn exec client -- curl -s -o /dev/null -w '%{http_code}' -m6 "$1" 2>/dev/null; }

exists() { kubectl -n fqdn get cnp client-egress; }
sel()    { eq "$(C '{.spec.endpointSelector.matchLabels.app}')" client; }
fqdn()   { C '{.spec.egress[*].toFQDNs[*].matchName}' | grep -qw example.com; }
dnsrule(){ C '{.spec.egress[*].toPorts[*].rules.dns[*].matchPattern}' | grep -q '\*'; }
https()  { C '{.spec.egress[*].toPorts[*].ports[*].port}' | grep -q 443; }
allowed(){ retry 5 3 bash -c "[ \"\$(kubectl -n fqdn exec client -- curl -s -o /dev/null -w '%{http_code}' -m6 https://example.com 2>/dev/null)\" = 200 ]"; }
blocked(){ [ "$(code https://www.wikipedia.org)" != 200 ] && [ "$(code https://www.wikipedia.org)" != 301 ]; }
dnsok()  { kubectl -n fqdn exec client -- nslookup example.com | grep -q Address; }

check "CiliumNetworkPolicy client-egress exists" exists
check "It selects Pods app=client" sel
check "It has a toFQDNs rule for example.com" fqdn
check "It has a DNS rule (matchPattern *) for the DNS proxy" dnsrule
check "Port 443 is allowed" https
check "https://example.com returns 200" allowed
check "https://www.wikipedia.org is blocked" blocked
check "DNS lookups still work" dnsok
finish
