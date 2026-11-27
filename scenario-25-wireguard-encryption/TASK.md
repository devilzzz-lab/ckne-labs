# Scenario 25 – WireGuard pod + node encryption

**Domain 4 – Network Security and Policy** · Session: **B (Cilium)** · Time: ~10 min

## Context

Traffic between Pods on different nodes crosses the node network in clear text. Namespace
`enc` has a `server` Pod on **node01** and a `client` Pod on the **controlplane** node, so
their traffic is cross-node.

## Task

1. Enable Cilium **transparent encryption** with **WireGuard** (`encryption.enabled=true`,
   `encryption.type=wireguard`) **and** also encrypt **node-to-node** traffic
   (`encryption.nodeEncryption=true`).
2. Restart the Cilium agents so the change takes effect.
3. Prove it: write the **number of WireGuard peers** reported by the Cilium agent into
   `/opt/answers/wg-peers.txt` (a single number).
4. The client must still reach the server (`curl http://server:8080` returns `server-ok`).

## Test AFTER fix

```bash
kubectl -n kube-system exec ds/cilium -- cilium-dbg status | grep Encryption
kubectl -n kube-system exec ds/cilium -- cilium-dbg encrypt status
kubectl -n enc exec client -- curl -s -m5 http://server:8080
# on a node: cross-node Pod traffic should appear only as UDP 51871 on the NIC
tcpdump -i any -nn -c 5 udp port 51871
```

## Hints

- `cilium upgrade --reuse-values --set ...`, then `kubectl -n kube-system rollout restart ds/cilium`.
- In `cilium-dbg status`, the line is `Encryption: Wireguard [... Peers: N]`.
- N should equal (number of nodes − 1).
- Docs: <https://docs.cilium.io/en/stable/security/network/encryption-wireguard/>
