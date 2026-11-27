# Solution – Scenario 29: Istio ambient STRICT mTLS

```bash
# 1. Enrol the namespace (no restarts)
kubectl label namespace bank istio.io/dataplane-mode=ambient

# 2. Refuse plaintext
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: bank
spec:
  mtls:
    mode: STRICT
EOF

# 3. Verify
istioctl ztunnel-config workloads | grep bank              # PROTOCOL = HBONE
kubectl -n bank    exec teller   -- curl -s -m5 http://ledger.bank | head -3     # works
kubectl -n outside exec intruder -- curl -s -m5 http://ledger.bank                # curl: (56) Recv failure: Connection reset
```

## Why

| Client | Server | PERMISSIVE (default) | STRICT |
|--------|--------|----------------------|--------|
| mesh | mesh | mTLS (HBONE) | mTLS |
| non-mesh | mesh | plaintext accepted | **rejected** |
| mesh | non-mesh | plaintext | plaintext |

- **ztunnel** (node DaemonSet) does the L4 work: HBONE tunnel, mTLS, SPIFFE identity per
  ServiceAccount. The namespace label makes istio-cni redirect the Pods' traffic into it.
  No sidecar, no restart.
- **PeerAuthentication = authentication** (who can connect, and is it mTLS?).
  **AuthorizationPolicy = authorization** (what may an authenticated caller do?). Know the
  difference, the exam does.
- A namespace-wide policy has no `selector` and is named `default`. A mesh-wide one lives
  in `istio-system`.
- Take one Pod out of the mesh with `istio.io/dataplane-mode=none` on the Pod.
- Health checks: kubelet probes are exempt, Istio handles them via SNAT to
  `169.254.7.127`.
