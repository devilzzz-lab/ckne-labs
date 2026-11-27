# Scenario 06 – Fix a Pod that cannot resolve cluster DNS

**Domain 1 – Core Infrastructure and CNI** · Session: A or B · Time: ~6 min

## Context

In namespace `conn`, Service `server` (nginx) works fine for other Pods. The Pod
`client` (image `curlimages/curl:8.8.0`) cannot reach it:

```bash
kubectl -n conn exec client -- curl -m3 http://server       # fails: could not resolve host
kubectl -n conn exec client -- curl -m3 http://server.conn.svc.cluster.local
```

Other names on the internet still resolve from `client`.

## Task

1. Find out why `client` cannot resolve cluster names.
2. Fix it. The Pod must keep the **name** `client`, namespace `conn` and the same image
   and command. Remember that most Pod fields are immutable.
3. Write the **IP address of the DNS server** the fixed Pod uses (from its
   `/etc/resolv.conf`) into `/opt/answers/dns-ip.txt`.

## Test AFTER fix

```bash
kubectl -n conn exec client -- curl -s -m3 http://server | head -3
kubectl -n conn exec client -- cat /etc/resolv.conf
```

## Hints

- `kubectl -n conn get pod client -o yaml | grep -i -A5 dns`
- Reference: <https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/#pod-s-dns-policy>
- Debugging guide: <https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/>
