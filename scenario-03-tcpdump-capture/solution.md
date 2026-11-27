# Solution – Scenario 03: Capture packets with tcpdump

```bash
ssh node01
tcpdump -i any -nn -c 25 -w /opt/captures/api.pcap dst port 8080
# wait until it prints "25 packets captured"

# verify
tcpdump -nn -r /opt/captures/api.pcap | wc -l                 # 25
tcpdump -nn -r /opt/captures/api.pcap 'dst port 8080' | wc -l  # 25
exit
```

## Why

| Flag | Meaning |
|------|---------|
| `-i any` | all interfaces (the pod veth, the node NIC, the tunnel) |
| `-nn` | no name/port resolution (faster, and exact numbers) |
| `-c 25` | stop after exactly 25 packets |
| `-w file` | write raw packets, read back with `-r file` |
| `dst port 8080` | capture filter, applied while capturing |

`-i any` shows the same flow more than once (veth and NIC). That is fine, the task
counts the packets in the file. Use an exact count, path and filter from the task.
Docs: <https://www.tcpdump.org/manpages/tcpdump.1.html>
