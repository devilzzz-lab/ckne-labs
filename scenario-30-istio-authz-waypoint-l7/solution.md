# Solution – Scenario 30: Istio waypoint + L7 policy

## Step 1 – Diagnose

```bash
kubectl -n bank exec teller -- curl -s -m5 -X POST http://ledger/transfer      # connection reset
kubectl -n bank get authorizationpolicy ledger-policy -o yaml | grep -A3 -E 'selector|methods|paths'
kubectl -n bank get gateway                                                      # no waypoint
kubectl -n istio-system logs -l app=ztunnel --tail=20 | grep -i -E 'denied|rejection'
```

The policy uses `selector`, so **ztunnel** enforces it. ztunnel is L4 only. It cannot
evaluate `methods` / `paths`, so it skips the rule, and with an ALLOW policy present and
no rule matching, **everything is denied**.

## Step 2 – Waypoint

```bash
istioctl waypoint apply -n bank --enroll-namespace --wait
kubectl -n bank get gateway waypoint
kubectl get ns bank --show-labels | grep use-waypoint
```

## Step 3 – Attach the policy to the Service (`targetRefs`)

```bash
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: ledger-policy
  namespace: bank
spec:
  targetRefs:
  - kind: Service
    group: ""
    name: ledger
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/bank/sa/teller"]
    to:
    - operation:
        methods: ["POST"]
        paths: ["/transfer"]
EOF
```

## Step 4 – Verify

```bash
kubectl -n bank exec teller  -- curl -s -o /dev/null -w '%{http_code}\n' -X POST http://ledger/transfer    # 200
kubectl -n bank exec teller  -- curl -s -o /dev/null -w '%{http_code}\n' http://ledger/transfer            # 403
kubectl -n bank exec auditor -- curl -s -o /dev/null -w '%{http_code}\n' -X POST http://ledger/transfer    # 403 (RBAC: access denied)
kubectl -n bank logs deploy/waypoint | tail
```

## Why

| Need | Resource |
|------|----------|
| Identity / port based (L4) | `AuthorizationPolicy` with `selector`, enforced by **ztunnel** |
| Method / path / header based (L7) | `AuthorizationPolicy` with `targetRefs`, enforced by a **waypoint** |

Symptom decoder:

| Symptom | Layer |
|---------|-------|
| `RBAC: access denied` (HTTP 403) | waypoint (L7) rejected it |
| `Connection reset` / `recv failure` | ztunnel (L4) rejected it, or STRICT mTLS rejected a non-mesh client |
| L7 ALLOW via `selector` blocks everything | ztunnel cannot evaluate the L7 rule (this lab) |
| L7-only DENY via `selector` does nothing | same reason, the rule is skipped |
| Policy has no effect | no waypoint, or the Service is not using it (`istio.io/use-waypoint`) |

Evaluation order: CUSTOM, then DENY, then ALLOW. Once any ALLOW policy targets a workload,
every request that matches none of its rules is denied. Principals look like
`cluster.local/ns/<ns>/sa/<sa>`. When a waypoint is in the path, a ztunnel-level policy on the
destination sees the **waypoint's** identity, not the client's.
