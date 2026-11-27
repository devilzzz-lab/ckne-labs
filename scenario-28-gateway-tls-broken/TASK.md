# Scenario 28 – Gateway TLS: fix a broken setup

**Domain 4 – Network Security and Policy** · Session: A or B · Time: ~12 min

## Context

The `store` team set up HTTPS for **`store.example.com`**, but it does not work. The
setup uses cert-manager with the (working) ClusterIssuer **`selfsigned`**. In namespace
`store`:

- Certificate `store-cert` (writes Secret `store-tls`)
- Gateway `store-gw` with an HTTPS listener `https` (443, `store.example.com`)
- HTTPRoute `store` for `store.example.com` → Service `store` (port 80, returns `store-secure`)

Symptoms: the Certificate is never Ready, the Gateway listener reports an unresolved
certificate reference, and the route has no parent that accepts it.

## Task

Find **all** the faults and fix them with minimal edits. Do **not** rename the Secret
`store-tls` that the Certificate is meant to produce and do not touch the ClusterIssuer.
At the end `https://store.example.com` must return `store-secure` and serve the
certificate cert-manager issued.

## Test AFTER fix

```bash
kubectl -n store get certificate,certificaterequest,secret
kubectl -n store describe gateway store-gw | grep -A12 Listeners
kubectl -n store describe httproute store
SVC=$(kubectl -n envoy-gateway-system get svc -l gateway.envoyproxy.io/owning-gateway-name=store-gw -o name)
kubectl -n envoy-gateway-system port-forward $SVC 10443:443 &
curl -vk --resolve store.example.com:10443:127.0.0.1 https://store.example.com:10443/
```

## Hints

- Work from the bottom up: Issuer → Certificate → Secret → Gateway listener → HTTPRoute.
- Read the **conditions** and **events** of each object. They name the problem.
- Docs: <https://cert-manager.io/docs/troubleshooting/> and
  <https://gateway-api.sigs.k8s.io/guides/tls/>
