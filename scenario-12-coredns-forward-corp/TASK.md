# Scenario 12 – CoreDNS: forward a corporate domain

**Domain 2 – Service Networking and DNS** · Session: A or B · Time: ~8 min

## Context

The company runs its own DNS server for the zone `corp.internal`. In this lab it is the
Service **`corp-dns`** in namespace **`dns-lab`** (a CoreDNS Pod that answers
`app.corp.internal` → `10.20.30.40`).

Pods currently cannot resolve it:

```bash
kubectl -n dns-lab exec toolbox -- nslookup app.corp.internal     # NXDOMAIN / not found
```

## Task

Change the cluster DNS (the `coredns` ConfigMap in `kube-system`) so that:

1. Every name under **`corp.internal`** is forwarded to the **ClusterIP of Service
   `corp-dns`**.
2. All other lookups stay exactly as they were (cluster names and the existing
   external forwarding keep working).
3. The change is active (restart CoreDNS if you do not want to wait for `reload`).

## Test AFTER fix

```bash
kubectl -n dns-lab exec toolbox -- nslookup app.corp.internal      # 10.20.30.40
kubectl -n dns-lab exec toolbox -- nslookup kubernetes.default
kubectl -n dns-lab exec toolbox -- nslookup example.com
```

## Hints

- `kubectl -n kube-system edit cm coredns`
- A separate **server block** for the zone, at the top level of the Corefile, not nested
  inside `.:53 { ... }`.
- Docs: <https://kubernetes.io/docs/tasks/administer-cluster/dns-custom-nameservers/>
  and <https://coredns.io/plugins/forward/>
