# Scenario 30 – Istio ambient: waypoint + L7 AuthorizationPolicy

**Domain 4 – Network Security and Policy** · Session: **Istio playground** (no Cilium BPF masquerade) · Time: ~15 min

## Context

Namespace **`bank`** is in the ambient mesh. Service `ledger` (port 80, an echo server
that answers **any** method and path) is called by two ServiceAccounts, each with a Pod:

| Pod | ServiceAccount |
|-----|----------------|
| `teller` | `teller` |
| `auditor` | `auditor` |

Someone already wrote an AuthorizationPolicy **`ledger-policy`**, but with the wrong
mechanism: it matches Pods with a `selector` and uses HTTP rules. Behaviour today: **every
request is denied** (connection reset), also the one that should work.

## Task

Make this the **only** allowed request:

> ServiceAccount **`teller`** may call **`POST /transfer`** on Service **`ledger`**.

Everything else must be denied with **HTTP 403** (`RBAC: access denied`), for example
`teller` doing `GET /transfer`, `teller` doing `POST /admin`, or `auditor` doing
`POST /transfer`.

1. Deploy a **waypoint** proxy for namespace `bank` and **enrol the namespace** to use it.
2. Fix **`ledger-policy`**: it must attach to the **Service** `ledger` (not select Pods).

## Test AFTER fix

```bash
kubectl -n bank get gateway waypoint
kubectl -n bank exec teller  -- curl -s -m5 -o /dev/null -w '%{http_code}\n' -X POST http://ledger/transfer   # 200
kubectl -n bank exec teller  -- curl -s -m5 -o /dev/null -w '%{http_code}\n' http://ledger/transfer           # 403
kubectl -n bank exec teller  -- curl -s -m5 -o /dev/null -w '%{http_code}\n' -X POST http://ledger/admin      # 403
kubectl -n bank exec auditor -- curl -s -m5 -o /dev/null -w '%{http_code}\n' -X POST http://ledger/transfer   # 403
```

## Hints

- `istioctl waypoint apply -n bank --enroll-namespace --wait`
- L7 attributes (methods, paths) are only visible to a **waypoint**. ztunnel is L4 only.
- Use `targetRefs` (kind `Service`, group `""`, name `ledger`) instead of `selector`.
- Principal format: `cluster.local/ns/<namespace>/sa/<serviceaccount>`.
- Docs: <https://istio.io/latest/docs/ambient/usage/l7-features/> and
  <https://istio.io/latest/docs/ambient/usage/waypoint/>
