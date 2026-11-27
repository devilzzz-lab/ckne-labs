# Solution – Scenario 27: cert-manager + Gateway

```bash
kubectl apply -f - <<'EOF'
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: app-cert
  namespace: secure
spec:
  secretName: app-tls
  dnsNames:
  - app.example.com
  issuerRef:
    name: selfsigned
    kind: ClusterIssuer
EOF

kubectl -n secure get certificate app-cert -w        # READY True
kubectl -n secure get secret app-tls

kubectl -n secure patch gateway secure-gw --type=json -p '[
  {"op":"add","path":"/spec/listeners/-","value":{
    "name":"https","protocol":"HTTPS","port":443,"hostname":"app.example.com",
    "tls":{"mode":"Terminate","certificateRefs":[{"kind":"Secret","name":"app-tls"}]},
    "allowedRoutes":{"namespaces":{"from":"Same"}}}}]'
```

Verify:

```bash
SVC=$(kubectl -n envoy-gateway-system get svc -l gateway.envoyproxy.io/owning-gateway-name=secure-gw -o name)
kubectl -n envoy-gateway-system port-forward $SVC 9443:443 &
curl -vk --resolve app.example.com:9443:127.0.0.1 https://app.example.com:9443/       # app-secure
```

## Why

- cert-manager turns a **Certificate** into a Secret: the controller creates a
  **CertificateRequest**, the **Issuer** signs it, and the result lands in `secretName`
  (and is renewed before it expires).
- A **ClusterIssuer** works in every namespace, an **Issuer** only in its own. `issuerRef.kind`
  must match. A wrong kind or name leaves the Certificate stuck `Ready=False`.
- Gateway annotation variant: annotate the Gateway with `cert-manager.io/cluster-issuer: <name>`
  and cert-manager creates the Certificate for each `certificateRefs` Secret on a listener
  that has `hostname` and `tls.mode: Terminate`. It needs the Helm value
  `config.enableGatewayAPI=true` on cert-manager (and the Gateway API CRDs present when
  cert-manager starts). The explicit Certificate used here works without it.
- Debug chain: `describe certificate` → `get certificaterequest` → `describe` it →
  `kubectl -n cert-manager logs deploy/cert-manager`.
- A real CA would use `acme` (Let's Encrypt) or `ca` issuers. Self-signed is for practice.
