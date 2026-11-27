# Scenario 04 – Find and remove a rogue iptables rule

**Domain 1 – Core Infrastructure and CNI** · Session: A or B · Time: ~6 min

## Context

A small web service runs directly on **node01**, listening on TCP **9090**. From the
controlplane node this works:

```bash
curl -m5 http://<node01-ip>:9090      # should print: ckne-web-ok
```

…but it **times out**. Someone left a firewall rule on node01 during a "maintenance
window". node01 also carries other custom firewall rules that **must stay**.

## Task

1. On node01, find the iptables rule that blocks the controlplane from reaching port 9090.
2. Delete **only that rule**. Do not flush chains and do not touch the other custom rules.
3. Confirm `curl` from the controlplane works again.

## Test AFTER fix

```bash
curl -m5 http://$(kubectl get node node01 -o jsonpath='{.status.addresses[0].address}'):9090
ssh node01 'iptables -S INPUT'
```

## Hints

- `iptables -L INPUT -n -v --line-numbers` or `iptables-save | grep 9090`
- Delete by line number (`-D INPUT <n>`) or by repeating the exact rule with `-D`.
- Rules are evaluated top to bottom. A `DROP` above an `ACCEPT` wins.
- Reference: <https://man7.org/linux/man-pages/man8/iptables.8.html>
