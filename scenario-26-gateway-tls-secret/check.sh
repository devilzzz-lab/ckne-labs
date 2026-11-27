#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
check_header "Scenario 26: Gateway HTTPS with a TLS Secret"
trap gw_forward_stop EXIT
LISTENER() { kubectl -n web get gateway web-gw -o jsonpath="{.spec.listeners[?(@.name==\"https\")]$1}" 2>/dev/null; }

secret_type() { eq "$(kubectl -n web get secret shop-tls -o jsonpath='{.type}')" kubernetes.io/tls; }
secret_cert() { eq "$(kubectl -n web get secret shop-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | tr -d '\n')" "$(tr -d '\n' < /opt/certs/shop.crt)"; }
l_port()      { eq "$(LISTENER '.port')" 443 && eq "$(LISTENER '.protocol')" HTTPS && eq "$(LISTENER '.hostname')" shop.example.com; }
l_tls()       { eq "$(LISTENER '.tls.mode')" Terminate && eq "$(LISTENER '.tls.certificateRefs[0].name')" shop-tls; }
http_kept()   { eq "$(kubectl -n web get gateway web-gw -o jsonpath='{.spec.listeners[?(@.name=="http")].port}')" 80; }
l_resolved()  { eq "$(kubectl -n web get gateway web-gw -o jsonpath='{.status.listeners[?(@.name=="https")].conditions[?(@.type=="ResolvedRefs")].status}')" True; }
r_section()   { eq "$(kubectl -n web get httproute shop -o jsonpath='{.spec.parentRefs[0].sectionName}')" https; }
r_acc()       { eq "$(kubectl -n web get httproute shop -o jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}')" True; }
served()      { eq "$(curl -sk -m6 --resolve shop.example.com:18443:127.0.0.1 https://shop.example.com:18443/)" shop-secure; }
cert_cn()     { echo | openssl s_client -connect 127.0.0.1:18443 -servername shop.example.com 2>/dev/null | openssl x509 -noout -subject | grep -q 'shop.example.com'; }
same_cert()   { local a b; a=$(echo | openssl s_client -connect 127.0.0.1:18443 -servername shop.example.com 2>/dev/null | openssl x509 -noout -fingerprint -sha256); b=$(openssl x509 -in /opt/certs/shop.crt -noout -fingerprint -sha256); eq "$a" "$b"; }

check "Secret shop-tls exists with type kubernetes.io/tls" secret_type
check "Secret holds the certificate from /opt/certs/shop.crt" secret_cert
check "Listener https: port 443, protocol HTTPS, hostname shop.example.com" l_port
check "Listener https: TLS Terminate with certificateRef shop-tls" l_tls
check "The http listener is still there" http_kept
check "Listener https has ResolvedRefs=True" l_resolved
check "HTTPRoute shop attaches to sectionName https" r_section
check "HTTPRoute shop is Accepted" r_acc
if gw_forward web web-gw 443 18443; then
  check "https://shop.example.com returns shop-secure" served
  check "The served certificate is for shop.example.com" cert_cn
  check "The served certificate is the one from /opt/certs" same_cert
else
  check "Envoy proxy for web-gw serves port 443 (port-forward)" false
fi
finish
