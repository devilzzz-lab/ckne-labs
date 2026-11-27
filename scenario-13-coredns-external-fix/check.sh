#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
check_header "Scenario 13: CoreDNS fix external lookups"
COREFILE() { kubectl -n kube-system get cm coredns -o jsonpath='{.data.Corefile}'; }

fwd_ok()      { COREFILE | grep -Eq '^[[:space:]]*forward[[:space:]]+\.[[:space:]]+1\.1\.1\.1([[:space:]]|\{|$)' && ! COREFILE | grep -E '^[[:space:]]*forward[[:space:]]+\.' | grep -Eq '10\.255\.255\.1|/etc/resolv'; }
kube_ok()     { COREFILE | grep -q 'kubernetes cluster.local'; }
external_ok() { retry 20 6 bash -c "kubectl -n dns-fix exec toolbox -- nslookup example.com 2>/dev/null | awk '/^Name:/{f=1} f&&/^Address/' | grep -q ."; }
cluster_ok()  { tbx dns-fix toolbox nslookup kubernetes.default.svc.cluster.local | grep -q 'Address'; }

check "Corefile forwards to 1.1.1.1 only" fwd_ok
check "The kubernetes plugin block is intact" kube_ok
check "nslookup example.com works (waits up to 2 min)" external_ok
check "Cluster names still resolve" cluster_ok
finish
