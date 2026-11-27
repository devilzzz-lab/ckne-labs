# Solution – Scenario 04: Find and remove a rogue iptables rule

```bash
ssh node01
iptables -L INPUT -n -v --line-numbers
#  num  pkts bytes target prot opt in out source      destination
#  1      0     0  DROP   udp  --  *  *   0.0.0.0/0   0.0.0.0/0   udp dpt:9098 /* ckne-metrics-keep */
#  2      0     0  DROP   tcp  --  *  *   0.0.0.0/0   0.0.0.0/0   tcp dpt:9099 /* ckne-legacy-keep */
#  3     12   720  DROP   tcp  --  *  *   <cp-ip>     0.0.0.0/0   tcp dpt:9090 /* ckne-maintenance */
```

Find the line that matches **port 9090 and the controlplane source IP**. The counters
(`pkts`) grow while you run `curl` from the controlplane. Delete just that line:

```bash
iptables -D INPUT 3          # use the number you saw
iptables -L INPUT -n --line-numbers   # the two "keep" rules are still there
exit
curl -m5 http://<node01-ip>:9090      # ckne-web-ok
```

Or delete it by specification (no line number):

```bash
iptables -D INPUT -p tcp -s <cp-ip> --dport 9090 -m comment --comment ckne-maintenance -j DROP
```

## Why

- Chains are matched top to bottom, first terminating match wins.
- Never `iptables -F` on a Kubernetes node. It also deletes the kube-proxy / CNI rules.
- `iptables-save | grep <ip>` is the fastest way to find a rule when you know an IP or port.
- The comment match (`-m comment`) is metadata only; it makes rules self-describing.
