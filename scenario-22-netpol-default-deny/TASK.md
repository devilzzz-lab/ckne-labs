# Scenario 22 – NetworkPolicy: default deny + allow-list

**Domain 4 – Network Security and Policy** · Session: A or B · Time: ~12 min

## Context

Namespace `lockdown` has three workloads. Today everything can talk to everything.

| Workload | Label | Detail |
|----------|-------|--------|
| `frontend` Pod | `app=frontend` | curl client |
| `other` Pod | `app=other` | curl client (must be **blocked**) |
| `api` Deployment + Service `api` | `app=api` | listens on TCP **8080**, returns `api-ok` |

The CNI (Calico or Cilium) enforces NetworkPolicy.

## Task

Using plain Kubernetes **NetworkPolicy** objects in namespace `lockdown`:

1. **Default deny** all ingress **and** egress for every Pod in the namespace
   (policy named **`default-deny`**).
2. **Allow DNS**: every Pod may send egress to the `kube-dns` Pods in `kube-system` on
   **UDP and TCP 53** (policy named **`allow-dns`**).
3. **`frontend` → `api` on TCP 8080** and nothing else. Remember that both sides must
   allow it: an **ingress** rule on `api` and an **egress** rule on `frontend`
   (policies named **`api-ingress`** and **`frontend-egress`**).

## Test AFTER fix

```bash
kubectl -n lockdown exec frontend -- curl -s -m3 http://api:8080     # api-ok
kubectl -n lockdown exec other    -- curl -s -m3 http://api:8080     # timeout (blocked)
kubectl -n lockdown exec frontend -- curl -s -m3 http://1.1.1.1      # timeout (blocked)
kubectl -n lockdown exec other    -- nslookup api                    # still resolves
```

## Hints

- `podSelector: {}` selects every Pod. `policyTypes: [Ingress, Egress]` turns on both directions.
- `kube-system` carries the label `kubernetes.io/metadata.name=kube-system`. Look up the DNS Pod labels with `kubectl -n kube-system get pods --show-labels`.
- `namespaceSelector` + `podSelector` in the **same** `to`/`from` item = AND.
- Docs: <https://kubernetes.io/docs/concepts/services-networking/network-policies/>
