# Scenario 26 – Gateway HTTPS with a TLS Secret

**Domain 4 – Network Security and Policy** · Session: A or B · Time: ~10 min

## Context

Gateway **`web-gw`** (namespace `web`, class `eg`) only has an HTTP listener on port 80.
A certificate and key for **`shop.example.com`** were issued for you:

```
/opt/certs/shop.crt
/opt/certs/shop.key
```

Backend Service `shop` (port 80) returns `shop-secure`.

## Task

1. Create a TLS **Secret** named **`shop-tls`** in namespace `web` from those two files.
2. Add an **HTTPS listener** named **`https`** to `web-gw`: port **443**, hostname
   `shop.example.com`, TLS mode **Terminate**, using Secret `shop-tls`.
   Keep the existing `http` listener.
3. Create an **HTTPRoute** named **`shop`** that attaches **only to the `https` listener**
   (`sectionName`) and sends everything for `shop.example.com` to Service `shop` port 80.

## Test AFTER fix

```bash
kubectl -n web get gateway web-gw -o yaml | grep -A12 'name: https'
SVC=$(kubectl -n envoy-gateway-system get svc -l gateway.envoyproxy.io/owning-gateway-name=web-gw -o name)
kubectl -n envoy-gateway-system port-forward $SVC 8443:443 &
curl -vk --resolve shop.example.com:8443:127.0.0.1 https://shop.example.com:8443/
openssl s_client -connect 127.0.0.1:8443 -servername shop.example.com </dev/null 2>/dev/null | openssl x509 -noout -subject -dates
```

## Hints

- `kubectl create secret tls --help`
- `kubectl explain gateway.spec.listeners.tls`
- The HTTPRoute `parentRefs` entry needs `sectionName: https`.
- Docs: <https://gateway-api.sigs.k8s.io/guides/tls/>
