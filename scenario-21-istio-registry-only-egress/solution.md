# Solution – Scenario 21: Istio registry-only egress

```bash
kubectl -n egress-lab apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: Sidecar
metadata:
  name: default
  namespace: egress-lab
spec:
  outboundTrafficPolicy:
    mode: REGISTRY_ONLY
---
apiVersion: networking.istio.io/v1
kind: ServiceEntry
metadata:
  name: ext-example
  namespace: egress-lab
spec:
  hosts:
  - example.com
  ports:
  - number: 80
    name: http
    protocol: HTTP
  location: MESH_EXTERNAL
  resolution: DNS
EOF

kubectl -n egress-lab exec curl-client -c curl -- curl -s -o /dev/null -w '%{http_code}\n' http://example.com   # 200
kubectl -n egress-lab exec curl-client -c curl -- curl -s -o /dev/null -w '%{http_code}\n' http://example.org   # 502
```

## Why

- `outboundTrafficPolicy` is `ALLOW_ANY` by default: unknown destinations are passed through
  (the `PassthroughCluster`). `REGISTRY_ONLY` sends them to the `BlackHoleCluster`, which
  answers **502** for HTTP.
- A **ServiceEntry** adds an external host to Istio's service registry, so it becomes
  routable and can carry traffic policy, retries, timeouts and telemetry.
- The same setting can be set mesh-wide with `meshConfig.outboundTrafficPolicy.mode`.
- This is sidecar-mode behaviour. In **ambient** mode ztunnel does not enforce
  `REGISTRY_ONLY`, and egress control uses waypoints / egress gateways instead.
- **Egress gateway** (the next step in a real design): a dedicated Envoy at the mesh edge.
  Sidecars send external traffic to it (`Gateway` + `VirtualService` + `DestinationRule`),
  and only the gateway Pods are allowed out by a NetworkPolicy. That gives one audited exit
  point and a predictable source.
