# Scenario 05 – Find and remove injected latency (tc netem)

**Domain 1 – Core Infrastructure and CNI** · Session: A or B · Time: ~5 min

## Context

On **node01** a test network exists: a network namespace `ckne-lab` connected to the
host with a veth pair. The host side is `veth-lab0` (`10.99.0.1/24`) and the
namespace side is `veth-lab1` (`10.99.0.2/24`).

From node01 this is slow:

```bash
ping -c3 10.99.0.2      # average RTT is about 300 ms (it should be < 1 ms)
```

## Task

1. On node01, find what adds the delay.
2. Remove it. Do **not** delete the veth devices or the `ckne-lab` namespace.
3. Confirm the ping RTT is back below 50 ms.

## Test AFTER fix

```bash
ssh node01 'ping -c3 -q 10.99.0.2'
ssh node01 'tc qdisc show dev veth-lab0'
```

## Hints

- `tc qdisc show` lists queueing disciplines per interface.
- The delay comes from the `netem` qdisc. Delete the root qdisc with `tc qdisc del dev <if> root`.
- Reference: <https://man7.org/linux/man-pages/man8/tc-netem.8.html>
