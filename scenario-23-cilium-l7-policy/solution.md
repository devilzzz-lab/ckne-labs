# Solution – Scenario 23: Cilium L7 policy

```bash
kubectl -n l7 apply -f - <<'EOF'
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: api-l7
spec:
  endpointSelector:
    matchLabels:
      app: api
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: frontend
    toPorts:
    - ports:
      - port: "8080"
        protocol: TCP
      rules:
        http:
        - method: GET
          path: "/products(/.*)?"
EOF

kubectl -n l7 exec frontend -- curl -s -o /dev/null -w '%{http_code}\n' http://api:8080/products/42   # 200
kubectl -n l7 exec frontend -- curl -s -o /dev/null -w '%{http_code}\n' http://api:8080/admin         # 403
hubble observe -n l7 --protocol http          # (if Hubble is enabled) shows FORWARDED / DENIED
```

## Why

- Adding `rules.http` to a `toPorts` entry sends that port's traffic through Cilium's
  Envoy proxy. Requests matching **no** rule get **403 Access denied**. The TCP
  connection itself was allowed.
- `path` and `method` are **regular expressions**, and the match is anchored. So
  `/products(/.*)?` matches `/products`, `/products/42` but **not** `/productsx`.
- Symptom decoder: *timeout* = dropped at L3/L4 (no rule for this identity or port).
  *403* = L4 allowed, L7 rejected. *Works for one path only* = regex too narrow.
- Use `cilium-dbg policy get` and `hubble observe --type policy-verdict` to see the
  decision that was taken.
