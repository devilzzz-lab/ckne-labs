# Scenario 03 – Capture packets with tcpdump

**Domain 1 – Core Infrastructure and CNI** · Session: A or B · Time: ~5 min

## Context

The Deployment `api` in namespace `shop` runs on **node01** and listens on TCP **8080**.
A client Pod keeps calling it. The network team wants proof of what arrives.

## Task

On node **node01** (use `ssh node01`), capture **exactly 25 packets** whose
**destination port is 8080**, on **any interface**, and save them to:

```
/opt/captures/api.pcap
```

Do not resolve names or ports (`-nn`). The file must contain exactly 25 packets, all
with destination port 8080.

## Test AFTER fix

```bash
ssh node01 'tcpdump -nn -r /opt/captures/api.pcap | wc -l'
ssh node01 'tcpdump -nn -r /opt/captures/api.pcap | head'
```

## Hints

- `-i any`, `-c <count>`, `-w <file>`, `-nn`, and a capture filter `dst port 8080`.
- Traffic is already flowing. Check with `kubectl -n shop get pods -o wide`.
- `man tcpdump`, section on filters. Docs: <https://www.tcpdump.org/manpages/tcpdump.1.html>
