# Scenario 15 – Gateway API path routing

**Domain 2 – Service Networking and DNS** · Session: A or B · Time: ~10 min

## Context

Envoy Gateway is installed and the GatewayClass **`eg`** exists (`kubectl get gatewayclass`).
Namespace `web` has two backends:

| Service | Port | Returns |
|---------|------|---------|
| `frontend` | 80 | `frontend` |
| `api` | 8080 | `api` |

## Task

In namespace `web`:

1. Create a **Gateway** named **`web-gw`**, `gatewayClassName: eg`, with one **HTTP**
   listener named **`http`** on port **80** for hostname **`shop.example.com`**. Routes from
   the **same namespace** are allowed.
2. Create an **HTTPRoute** named **`shop`** attached to that listener, for hostname
   `shop.example.com`:
   - requests with path prefix **`/api`** → Service `api`, port 8080
   - **all other** requests → Service `frontend`, port 80

## Test AFTER fix

```bash
kubectl -n web get gateway web-gw
kubectl -n web describe httproute shop          # Accepted=True, ResolvedRefs=True

# no external IP on Killercoda, so use a port-forward to the Envoy Service:
SVC=$(kubectl -n envoy-gateway-system get svc -l gateway.envoyproxy.io/owning-gateway-name=web-gw -o name)
kubectl -n envoy-gateway-system port-forward $SVC 8080:80 &
curl -s -H 'Host: shop.example.com' localhost:8080/api         # api
curl -s -H 'Host: shop.example.com' localhost:8080/            # frontend
```

## Hints

- `kubectl explain gateway.spec.listeners` / `kubectl explain httproute.spec.rules`
- Gateway docs: <https://gateway-api.sigs.k8s.io/reference/api-types/gateway/>
- HTTPRoute docs: <https://gateway-api.sigs.k8s.io/reference/api-types/httproute/>
- Envoy Gateway: <https://gateway.envoyproxy.io/docs/tasks/traffic/http-routing/>
