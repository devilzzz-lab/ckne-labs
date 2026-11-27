# Scenario 13 – CoreDNS: fix external lookups

**Domain 2 – Service Networking and DNS** · Session: A or B · Time: ~6 min

## Context

Pods in namespace `dns-fix` resolve cluster names, but **external names time out**:

```bash
kubectl -n dns-fix exec toolbox -- nslookup kubernetes.default     # works
kubectl -n dns-fix exec toolbox -- nslookup example.com             # times out
```

## Task

Fix cluster DNS so that every lookup that is **not** a cluster name is forwarded to the
public resolver **`1.1.1.1`** (and only to it). Do not break cluster names, and keep the
rest of the Corefile as it is.

## Test AFTER fix

```bash
kubectl -n dns-fix exec toolbox -- nslookup example.com
kubectl -n dns-fix exec toolbox -- nslookup kubernetes.default
kubectl -n kube-system logs -l k8s-app=kube-dns --tail=20
```

## Hints

- Look at the `forward` line inside the `.:53` block.
- The CoreDNS logs show `i/o timeout` against the upstream when the target is wrong.
- Docs: <https://coredns.io/plugins/forward/>,
  <https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/>
