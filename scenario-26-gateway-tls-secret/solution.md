# Solution – Scenario 26: Gateway HTTPS with a TLS Secret

```bash
kubectl -n web create secret tls shop-tls --cert=/opt/certs/shop.crt --key=/opt/certs/shop.key

kubectl apply -f - <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: web-gw
  namespace: web
spec:
  gatewayClassName: eg
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    hostname: shop.example.com
    allowedRoutes:
      namespaces:
        from: Same
  - name: https
    protocol: HTTPS
    port: 443
    hostname: shop.example.com
    tls:
      mode: Terminate
      certificateRefs:
      - kind: Secret
        name: shop-tls
    allowedRoutes:
      namespaces:
        from: Same
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: shop
  namespace: web
spec:
  parentRefs:
  - name: web-gw
    sectionName: https
  hostnames:
  - shop.example.com
  rules:
  - backendRefs:
    - name: shop
      port: 80
EOF
```

## Verify

```bash
kubectl -n web describe gateway web-gw | grep -B2 -A6 https
SVC=$(kubectl -n envoy-gateway-system get svc -l gateway.envoyproxy.io/owning-gateway-name=web-gw -o name)
kubectl -n envoy-gateway-system port-forward $SVC 8443:443 &
curl -vk --resolve shop.example.com:8443:127.0.0.1 https://shop.example.com:8443/        # shop-secure
openssl s_client -connect 127.0.0.1:8443 -servername shop.example.com </dev/null 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates
```

## Why

- The listener `tls.certificateRefs` points at a Secret of type `kubernetes.io/tls` in the
  **Gateway's namespace**. Another namespace needs a **ReferenceGrant** in the Secret's
  namespace (`RefNotPermitted` otherwise).
- `sectionName` binds the route to one listener. Without it the route attaches to every
  listener it is allowed on.
- SNI selects the listener. Always pass `--resolve` / `-servername` with the real hostname,
  or you test the wrong listener.
- Troubleshooting table: listener `ResolvedRefs=False` + `InvalidCertificateRef` = missing
  Secret, wrong name, or wrong type. Expired or wrong-name certificate = read `-dates` and
  the SAN from `openssl x509`.
- `tls.mode: Passthrough` + `TLSRoute` forwards encrypted bytes to the backend untouched.
