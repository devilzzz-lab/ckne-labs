# Solution – Scenario 12: CoreDNS forward a corporate domain

```bash
CIP=$(kubectl -n dns-lab get svc corp-dns -o jsonpath='{.spec.clusterIP}')
kubectl -n kube-system edit cm coredns
```

Add a **new top-level block** after the existing `.:53 { ... }` block. Leave everything
else untouched:

```text
.:53 {
    errors
    health { lameduck 5s }
    ready
    kubernetes cluster.local in-addr.arpa ip6.arpa {
       pods insecure
       fallthrough in-addr.arpa ip6.arpa
       ttl 30
    }
    prometheus :9153
    forward . /etc/resolv.conf { max_concurrent 1000 }
    cache 30
    loop
    reload
    loadbalance
}
corp.internal:53 {
    errors
    cache 30
    forward . <CIP of corp-dns>
}
```

```bash
kubectl -n kube-system rollout restart deploy coredns
kubectl -n kube-system rollout status deploy coredns
kubectl -n dns-lab exec toolbox -- nslookup app.corp.internal      # 10.20.30.40
```

## Why

- CoreDNS picks the server block with the **longest matching zone**. `corp.internal`
  beats `.`, so only that zone goes to the corporate server.
- Putting `forward . <ip>` in the `.:53` block instead would send **all** external
  lookups to the corporate server (that is scenario 13's situation).
- The `reload` plugin re-reads the ConfigMap after the kubelet syncs it, which can take
  up to ~2 minutes. `rollout restart` is faster.
- If something breaks: `kubectl -n kube-system logs -l k8s-app=kube-dns`. A syntax error
  keeps the old config running and logs the error.
