# Solution – Scenario 15: Gateway API path routing

```bash
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
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: shop
  namespace: web
spec:
  parentRefs:
  - name: web-gw
    sectionName: http
  hostnames:
  - shop.example.com
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /api
    backendRefs:
    - name: api
      port: 8080
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: frontend
      port: 80
EOF

kubectl -n web get gateway web-gw
kubectl -n web describe httproute shop | grep -A12 'Status:'
```

Test (no external IP on Killercoda, so port-forward the generated Envoy Service):

```bash
SVC=$(kubectl -n envoy-gateway-system get svc \
  -l gateway.envoyproxy.io/owning-gateway-name=web-gw,gateway.envoyproxy.io/owning-gateway-namespace=web -o name)
kubectl -n envoy-gateway-system port-forward $SVC 8080:80 &
curl -s -H 'Host: shop.example.com' localhost:8080/api       # api
curl -s -H 'Host: shop.example.com' localhost:8080/          # frontend
```

## Why

- **GatewayClass** → who implements it. **Gateway** → listeners (port, protocol, hostname,
  TLS, allowed routes). **HTTPRoute** → matching and backends, attached through `parentRefs`.
- The most specific match wins (longest path prefix), so `/api` is checked before `/`.
- Without an LB implementation the Gateway shows `Programmed` but has no address. That is
  expected here.
- If the route is not Accepted, read `status.parents[].conditions[].reason`. The table of
  reasons is in `study/02-service-networking-dns.md`.
