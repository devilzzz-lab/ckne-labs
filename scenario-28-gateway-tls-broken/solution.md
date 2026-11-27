# Solution – Scenario 28: Gateway TLS troubleshooting

Three independent faults. Walk the chain bottom-up.

| # | Where | Symptom | Cause | Fix |
|---|-------|---------|-------|-----|
| 1 | Certificate `store-cert` | never `Ready`; `describe` shows `Issuer "selfsign" not found` | `issuerRef.name: selfsign` (typo) | `selfsigned` |
| 2 | Gateway `store-gw` listener `https` | `ResolvedRefs=False`, reason `InvalidCertificateRef` | `certificateRefs[0].name: store-tls-cert`, but the Certificate writes `store-tls` | `store-tls` |
| 3 | HTTPRoute `store` | no accepted parent, `Accepted=False` / `NoMatchingParent` | `sectionName: htps` matches no listener | `https` |

```bash
# 1. Certificate: point at the real issuer (issuerRef is mutable)
kubectl -n store patch certificate store-cert --type=merge -p '{"spec":{"issuerRef":{"name":"selfsigned","kind":"ClusterIssuer"}}}'
kubectl -n store get certificate store-cert -w                   # Ready=True
kubectl -n store get secret store-tls

# 2. Gateway listener: reference the Secret that exists
kubectl -n store patch gateway store-gw --type=json -p \
  '[{"op":"replace","path":"/spec/listeners/0/tls/certificateRefs/0/name","value":"store-tls"}]'

# 3. HTTPRoute: attach to the real listener name
kubectl -n store patch httproute store --type=json -p \
  '[{"op":"replace","path":"/spec/parentRefs/0/sectionName","value":"https"}]'
```

Verify:

```bash
kubectl -n store describe gateway store-gw | grep -B2 -A8 'Resolved'
kubectl -n store describe httproute store | grep -A6 Conditions
SVC=$(kubectl -n envoy-gateway-system get svc -l gateway.envoyproxy.io/owning-gateway-name=store-gw -o name)
kubectl -n envoy-gateway-system port-forward $SVC 10443:443 &
curl -vk --resolve store.example.com:10443:127.0.0.1 https://store.example.com:10443/      # store-secure
```

## Why

Triage order for "HTTPS on a Gateway does not work":

1. **Is there a Secret?** `kubectl get secret`. If not, why not? (`describe certificate`,
   `get certificaterequest`, issuer exists and Ready, cert-manager logs.)
2. **Does the listener resolve it?** Gateway `status.listeners[].conditions`: `InvalidCertificateRef`
   (missing/wrong name/type) or `RefNotPermitted` (other namespace without ReferenceGrant).
3. **Is the route attached?** `status.parents[]`: `NoMatchingParent` (name or sectionName),
   `NotAllowedByListeners`, `NoMatchingListenerHostname`.
4. **What does the client really see?** `openssl s_client -servername <host>` for the served
   certificate (subject, SAN, dates).
