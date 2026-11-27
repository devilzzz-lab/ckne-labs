#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
check_header "Scenario 06: Fix a Pod that cannot resolve cluster DNS"
KUBEDNS=$(kubectl -n kube-system get svc kube-dns -o jsonpath='{.spec.clusterIP}')

policy_ok() { local p; p=$(kubectl -n conn get pod client -o jsonpath='{.spec.dnsPolicy}'); [ "$p" = ClusterFirst ] || [ -z "$p" ]; }
image_ok()  { eq "$(kubectl -n conn get pod client -o jsonpath='{.spec.containers[0].image}')" "curlimages/curl:8.8.0"; }
resolv_ok() { tbx conn client cat /etc/resolv.conf | grep -q "nameserver $KUBEDNS"; }
short_ok()  { tbx conn client curl -s -m5 http://server | grep -q "nginx"; }
fqdn_ok()   { tbx conn client curl -s -m5 -o /dev/null -w '%{http_code}' http://server.conn.svc.cluster.local | grep -q 200; }
answer_ok() { eq "$(ans dns-ip.txt)" "$KUBEDNS"; }

check "Pod client has dnsPolicy ClusterFirst" policy_ok
check "Pod client still uses image curlimages/curl:8.8.0" image_ok
check "client's resolv.conf points at the kube-dns Service ($KUBEDNS)" resolv_ok
check "curl http://server (short name) works" short_ok
check "curl http://server.conn.svc.cluster.local works" fqdn_ok
check "/opt/answers/dns-ip.txt contains $KUBEDNS" answer_ok
finish
