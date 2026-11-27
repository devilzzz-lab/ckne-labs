# Solution – Scenario 13: CoreDNS fix external lookups

## Step 1 – Diagnose

```bash
kubectl -n dns-fix exec toolbox -- nslookup example.com       # ;; connection timed out
kubectl -n kube-system logs -l k8s-app=kube-dns --tail=20
#   [ERROR] plugin/errors: 2 example.com. A: read udp ...->10.255.255.1:53: i/o timeout
kubectl -n kube-system get cm coredns -o yaml | grep -n forward
#   forward . 10.255.255.1 { max_concurrent 1000 }
```

Cluster names are answered by the `kubernetes` plugin and never reach `forward`. Only
the upstream is broken.

## Step 2 – Fix the forward target

```bash
kubectl -n kube-system edit cm coredns
```

change

```text
    forward . 10.255.255.1 {
```

to

```text
    forward . 1.1.1.1 {
```

```bash
kubectl -n kube-system rollout restart deploy coredns
kubectl -n dns-fix exec toolbox -- nslookup example.com
```

## Why

- `forward . /etc/resolv.conf` (the default) sends non-cluster queries to the node's
  resolvers. Setting an IP overrides that.
- If lookups still hang after a correct edit, check that no NetworkPolicy blocks CoreDNS
  egress on UDP/TCP 53, and that the node can reach the upstream.
- A typo in the Corefile does not take effect. CoreDNS keeps the last good config and
  logs the parse error.
