#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
check_header "Scenario 27: cert-manager + Gateway"
trap gw_forward_stop EXIT
L() { kubectl -n secure get gateway secure-gw -o jsonpath="{.spec.listeners[?(@.name==\"https\")]$1}" 2>/dev/null; }
CE() { kubectl -n secure get certificate app-cert -o jsonpath="$1" 2>/dev/null; }

ci_ok()    { kubectl get clusterissuer selfsigned -o jsonpath='{.spec.selfSigned}' | grep -q '{'; }
ci_ready() { eq "$(kubectl get clusterissuer selfsigned -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')" True; }
cert_cfg() { eq "$(CE '{.spec.secretName}')" app-tls && CE '{.spec.dnsNames[*]}' | grep -qw app.example.com && eq "$(CE '{.spec.issuerRef.name}')" selfsigned && eq "$(CE '{.spec.issuerRef.kind}')" ClusterIssuer; }
cert_ready(){ retry 10 3 bash -c "[ \"\$(kubectl -n secure get certificate app-cert -o jsonpath='{.status.conditions[?(@.type==\"Ready\")].status}')\" = True ]"; }
secret_ok(){ eq "$(kubectl -n secure get secret app-tls -o jsonpath='{.type}')" kubernetes.io/tls; }
l_cfg()    { eq "$(L '.port')" 443 && eq "$(L '.hostname')" app.example.com && eq "$(L '.tls.mode')" Terminate && eq "$(L '.tls.certificateRefs[0].name')" app-tls; }
l_res()    { eq "$(kubectl -n secure get gateway secure-gw -o jsonpath='{.status.listeners[?(@.name=="https")].conditions[?(@.type=="ResolvedRefs")].status}')" True; }
served()   { eq "$(curl -sk -m6 --resolve app.example.com:19443:127.0.0.1 https://app.example.com:19443/)" app-secure; }
same()     { local a b; a=$(echo | openssl s_client -connect 127.0.0.1:19443 -servername app.example.com 2>/dev/null | openssl x509 -noout -fingerprint -sha256); b=$(kubectl -n secure get secret app-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -fingerprint -sha256); eq "$a" "$b"; }

check "ClusterIssuer selfsigned (selfSigned) exists" ci_ok
check "ClusterIssuer selfsigned is Ready" ci_ready
check "Certificate app-cert: app-tls, app.example.com, issuer selfsigned" cert_cfg
check "Certificate app-cert is Ready" cert_ready
check "Secret app-tls exists (type kubernetes.io/tls)" secret_ok
check "Gateway listener https: 443, app.example.com, Terminate, secret app-tls" l_cfg
check "Listener https has ResolvedRefs=True" l_res
if gw_forward secure secure-gw 443 19443; then
  check "https://app.example.com returns app-secure" served
  check "The Gateway serves the certificate cert-manager issued" same
else
  check "Envoy proxy for secure-gw serves port 443 (port-forward)" false
fi
finish
