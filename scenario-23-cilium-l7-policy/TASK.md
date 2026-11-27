# Scenario 23 – Cilium L7 HTTP policy

**Domain 4 – Network Security and Policy** · Session: **B (Cilium)** · Time: ~10 min

## Context

Namespace `l7` has Service `api` (port **8080**, answers **200 on every path**) and a
`frontend` Pod (`app=frontend`, curl). Plain NetworkPolicy can only say "frontend may use
port 8080". The business wants more.

## Task

Create a **`CiliumNetworkPolicy`** named **`api-l7`** in namespace `l7` that applies to
Pods `app=api` and, for ingress from Pods `app=frontend` on **TCP 8080**, allows **only**:

- **`GET`** on **`/products`** and on anything below it (`/products/42`, ...)

Every other request from `frontend` (other paths, other methods) must be rejected with
**HTTP 403**.

## Test AFTER fix

```bash
kubectl -n l7 exec frontend -- curl -s -o /dev/null -w '%{http_code}\n' http://api:8080/products        # 200
kubectl -n l7 exec frontend -- curl -s -o /dev/null -w '%{http_code}\n' http://api:8080/products/42     # 200
kubectl -n l7 exec frontend -- curl -s -o /dev/null -w '%{http_code}\n' http://api:8080/admin           # 403
kubectl -n l7 exec frontend -- curl -s -o /dev/null -w '%{http_code}\n' -X POST http://api:8080/products   # 403
```

## Hints

- `ingress[].toPorts[].rules.http[]` with `method` and `path`. Both are **regular expressions**.
- A single path regex can cover both `/products` and `/products/...`.
- 403 = allowed at L4, rejected at L7. A timeout would mean it was dropped at L3/L4.
- Docs: <https://docs.cilium.io/en/stable/security/policy/language/#layer-7-examples>
