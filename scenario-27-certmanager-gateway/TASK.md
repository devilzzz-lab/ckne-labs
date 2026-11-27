# Scenario 27 – cert-manager issues the Gateway certificate

**Domain 4 – Network Security and Policy** · Session: Any playground · Time: ~12 min

## Context

cert-manager is installed. Namespace `secure` has Service `app` (port 80, returns
`app-secure`), Gateway **`secure-gw`** with only an HTTP listener, and an HTTPRoute
**`app`** (no `sectionName`) for hostname **`app.example.com`**.

No certificate exists. Nobody should create the Secret by hand.

## Task

1. Create a **ClusterIssuer** named **`selfsigned`** (type `selfSigned`).
2. In namespace `secure`, create a **Certificate** named **`app-cert`**:
   `dnsNames: [app.example.com]`, `secretName: app-tls`, `issuerRef` → ClusterIssuer
   `selfsigned`.
3. Wait until the Certificate is **Ready** and Secret `app-tls` exists.
4. Add an **HTTPS listener** named **`https`** to `secure-gw` (port **443**, hostname
   `app.example.com`, mode **Terminate**) that uses Secret **`app-tls`**.

## Test AFTER fix

```bash
kubectl get clusterissuer selfsigned
kubectl -n secure get certificate,certificaterequest
kubectl -n secure get secret app-tls
SVC=$(kubectl -n envoy-gateway-system get svc -l gateway.envoyproxy.io/owning-gateway-name=secure-gw -o name)
kubectl -n envoy-gateway-system port-forward $SVC 9443:443 &
curl -vk --resolve app.example.com:9443:127.0.0.1 https://app.example.com:9443/
```

## Hints

- `kubectl -n secure describe certificate app-cert` shows why it is not Ready.
- cert-manager chain: **Issuer → Certificate → CertificateRequest → Order/Secret**.
- Docs: <https://cert-manager.io/docs/configuration/selfsigned/> and
  <https://cert-manager.io/docs/usage/certificate/>
- Gateway annotation variant: <https://cert-manager.io/docs/usage/gateway/>
