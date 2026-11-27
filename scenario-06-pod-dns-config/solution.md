# Solution – Scenario 06: Fix a Pod that cannot resolve cluster DNS

## Step 1 – Diagnose

```bash
kubectl -n conn exec client -- cat /etc/resolv.conf
#   search example.local
#   nameserver 8.8.8.8            <- NOT the cluster DNS (10.96.0.10 or similar)

kubectl -n conn get pod client -o jsonpath='{.spec.dnsPolicy}{"\n"}'     # None
kubectl -n kube-system get svc kube-dns
```

`dnsPolicy: None` + `dnsConfig` replaced the cluster resolver with 8.8.8.8, which knows
nothing about `*.svc.cluster.local`. Internet names still work, which is the clue.

## Step 2 – Recreate the Pod with the default policy

`dnsPolicy` is immutable, so the Pod has to be recreated:

```bash
kubectl -n conn get pod client -o yaml > /tmp/client.yaml
# edit /tmp/client.yaml: delete dnsPolicy and the whole dnsConfig block
#   (or set dnsPolicy: ClusterFirst), then:
kubectl replace --force -f /tmp/client.yaml
```

Or in one go:

```bash
kubectl -n conn delete pod client --now
kubectl -n conn run client --image=curlimages/curl:8.8.0 --command -- sleep infinity
```

## Step 3 – Verify and write the answer

```bash
kubectl -n conn exec client -- curl -s -m3 http://server | head -3
kubectl -n kube-system get svc kube-dns -o jsonpath='{.spec.clusterIP}' > /opt/answers/dns-ip.txt
kubectl -n conn exec client -- grep nameserver /etc/resolv.conf     # same IP
```

## Why

| `dnsPolicy` | Result |
|-------------|--------|
| `ClusterFirst` (default) | Cluster DNS first, unmatched names go to the node's upstream |
| `Default` | The node's resolv.conf only. Cluster names do **not** resolve |
| `None` | Only what `dnsConfig` says |
| `ClusterFirstWithHostNet` | Needed for `hostNetwork: true` Pods that still want cluster DNS |
