# Solution – Scenario 05: Find and remove injected latency

```bash
ssh node01

# 1. Measure
ping -c3 10.99.0.2                    # ~300 ms

# 2. Look for shaping on the interface
tc qdisc show dev veth-lab0
#   qdisc netem 8001: root refcnt 2 limit 1000 delay 300ms

# 3. Remove it
tc qdisc del dev veth-lab0 root

# 4. Verify
ping -c3 -q 10.99.0.2                 # < 1 ms
exit
```

## Why

- Slow-but-working traffic usually means **queueing, shaping or retransmits**, not routing.
- `tc qdisc show` (all interfaces) or `tc qdisc show dev <if>` is the first command to run.
- `netem` can add `delay`, `loss`, `duplicate` and `corrupt`. All are removed by deleting
  the root qdisc.
- Other places latency hides: `ss -tni` (retransmits, rtt), `ethtool -S <if> | grep -i drop`,
  and MTU mismatches (large packets fail but small ones pass).
