#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
check_header "Scenario 12: CoreDNS forward a corporate domain"
CIP=$(kubectl -n dns-lab get svc corp-dns -o jsonpath='{.spec.clusterIP}')
COREFILE() { kubectl -n kube-system get cm coredns -o jsonpath='{.data.Corefile}'; }

block_ok()    { COREFILE | grep -Eq '^[[:space:]]*corp\.internal\.?(:53)?[[:space:]]*\{'; }
fwd_ok()      { COREFILE | awk '/^[[:space:]]*corp\.internal/{f=1} f&&/forward/{print; exit}' | grep -Eq "forward[[:space:]]+\.[[:space:]]+${CIP//./\\.}([[:space:]]|\$)"; }
default_ok()  { COREFILE | grep -Eq '^\.:53[[:space:]]*\{' && COREFILE | grep -q 'kubernetes cluster.local'; }
corp_works()  { retry 20 6 bash -c "kubectl -n dns-lab exec toolbox -- nslookup app.corp.internal 2>/dev/null | grep -q 10.20.30.40"; }
cluster_ok()  { tbx dns-lab toolbox nslookup kubernetes.default.svc.cluster.local | grep -q 'Address'; }
external_ok() { retry 3 3 bash -c "kubectl -n dns-lab exec toolbox -- nslookup example.com 2>/dev/null | awk '/^Name:/{f=1} f&&/^Address/' | grep -q ."; }

check "Corefile has a top-level server block for corp.internal" block_ok
check "That block forwards to the corp-dns ClusterIP ($CIP)" fwd_ok
check "The default .:53 block with the kubernetes plugin is intact" default_ok
check "nslookup app.corp.internal returns 10.20.30.40 (waits up to 2 min)" corp_works
check "Cluster names still resolve" cluster_ok
check "External names still resolve" external_ok
finish
