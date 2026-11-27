# Solution – Scenario 24: Cilium FQDN egress

```bash
kubectl -n fqdn apply -f - <<'EOF'
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: client-egress
spec:
  endpointSelector:
    matchLabels:
      app: client
  egress:
  - toEndpoints:
    - matchLabels:
        k8s:io.kubernetes.pod.namespace: kube-system
        k8s:k8s-app: kube-dns
    toPorts:
    - ports:
      - port: "53"
        protocol: ANY
      rules:
        dns:
        - matchPattern: "*"
  - toFQDNs:
    - matchName: example.com
    toPorts:
    - ports:
      - port: "443"
        protocol: TCP
EOF

kubectl -n fqdn exec client -- curl -s -o /dev/null -w '%{http_code}\n' -m6 https://example.com           # 200
kubectl -n fqdn exec client -- curl -s -o /dev/null -w '%{http_code}\n' -m6 https://www.wikipedia.org     # 000
```

## Why

- Cilium cannot filter by DNS name directly. It runs a **DNS proxy**, watches the answers
  to the Pod's lookups and **learns which IPs belong to `example.com`**. The `toFQDNs`
  rule then allows exactly those IPs.
- No DNS rule → the proxy never sees the answers → `toFQDNs` allows nothing. This is the
  top reason an FQDN policy "does not work".
- As soon as any egress rule selects a Pod, every other egress is denied (default deny).
- `matchName` is an exact name. `matchPattern: "*.example.com"` is a wildcard.
- Explicit **deny** rules (`egressDeny`) cannot use `toFQDNs` or L7 rules.
