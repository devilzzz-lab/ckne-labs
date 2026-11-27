#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
check_header "Scenario 28: Gateway TLS troubleshooting"
trap gw_forward_stop EXIT

issuer_ok() { eq "$(kubectl get clusterissuer selfsigned -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')" True; }
secret_name(){ eq "$(kubectl -n store get certificate store-cert -o jsonpath='{.spec.secretName}')" store-tls; }
cert_ready(){ retry 15 3 bash -c "[ \"\$(kubectl -n store get certificate store-cert -o jsonpath='{.status.conditions[?(@.type==\"Ready\")].status}')\" = True ]"; }
secret_ok() { eq "$(kubectl -n store get secret store-tls -o jsonpath='{.type}')" kubernetes.io/tls; }
l_ref()     { eq "$(kubectl -n store get gateway store-gw -o jsonpath='{.spec.listeners[0].tls.certificateRefs[0].name}')" store-tls; }
l_res()     { retry 10 3 bash -c "[ \"\$(kubectl -n store get gateway store-gw -o jsonpath='{.status.listeners[?(@.name==\"https\")].conditions[?(@.type==\"ResolvedRefs\")].status}')\" = True ]"; }
r_acc()     { retry 10 3 bash -c "[ \"\$(kubectl -n store get httproute store -o jsonpath='{.status.parents[0].conditions[?(@.type==\"Accepted\")].status}')\" = True ]"; }
served()    { eq "$(curl -sk -m6 --resolve store.example.com:20443:127.0.0.1 https://store.example.com:20443/)" store-secure; }
same()      { local a b; a=$(echo | openssl s_client -connect 127.0.0.1:20443 -servername store.example.com 2>/dev/null | openssl x509 -noout -fingerprint -sha256); b=$(kubectl -n store get secret store-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -fingerprint -sha256); eq "$a" "$b"; }

check "ClusterIssuer selfsigned is untouched and Ready" issuer_ok
check "Certificate still writes Secret store-tls" secret_name
check "Certificate store-cert becomes Ready" cert_ready
check "Secret store-tls exists (kubernetes.io/tls)" secret_ok
check "Gateway listener references Secret store-tls" l_ref
check "Gateway listener has ResolvedRefs=True" l_res
check "HTTPRoute store is Accepted by the Gateway" r_acc
if gw_forward store store-gw 443 20443; then
  check "https://store.example.com returns store-secure" served
  check "The Gateway serves the cert-manager certificate" same
else
  check "Envoy proxy for store-gw serves port 443 (port-forward)" false
fi
finish
