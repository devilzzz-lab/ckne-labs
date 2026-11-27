# Solution – Scenario 25: WireGuard pod + node encryption

```bash
# keep the running version: `cilium upgrade` without --version moves to the CLI's default version
CV=$(kubectl -n kube-system get ds cilium -o jsonpath='{.spec.template.spec.containers[0].image}' | sed -E 's/.*:v?([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
cilium upgrade --version $CV --reuse-values \
  --set encryption.enabled=true \
  --set encryption.type=wireguard \
  --set encryption.nodeEncryption=true
kubectl -n kube-system rollout restart ds/cilium
kubectl -n kube-system rollout status ds/cilium

# verify
kubectl -n kube-system exec ds/cilium -- cilium-dbg status | grep Encryption
#   Encryption:  Wireguard   [NodeEncryption: Enabled, cilium_wg0 (Pubkey: ..., Port: 51871, Peers: 1)]
kubectl -n kube-system exec ds/cilium -- cilium-dbg encrypt status
cilium config view | grep -iE 'wireguard|encrypt'

# the answer (peers = nodes - 1 = 1 on this 2-node cluster)
kubectl -n kube-system exec ds/cilium -- cilium-dbg status | grep Encryption \
  | sed -n 's/.*Peers: \([0-9]*\).*/\1/p' > /opt/answers/wg-peers.txt

kubectl -n enc exec client -- curl -s http://server:8080          # server-ok
```

Prove it on the wire (on a node, while the client calls the server):

```bash
tcpdump -i any -nn -c 10 udp port 51871      # encrypted WireGuard packets between nodes
tcpdump -i any -nn -c 10 tcp port 8080       # plaintext only on the cilium_wg0 device / pod veth, not on the NIC
```

## Why

- Each node generates a WireGuard key pair and publishes the public key on its
  `CiliumNode`. Cross-node Pod traffic is tunnelled through `cilium_wg0` (UDP **51871**).
  Pods on the **same node** talk directly and stay unencrypted.
- `nodeEncryption=true` also encrypts **host (node-to-node)** traffic. Without it only Pod
  traffic is encrypted.
- `Peers: 0` or plaintext TCP 8080 on the NIC means encryption is not in effect: agents
  not restarted, or the node lacks WireGuard kernel support (needs kernel 5.6+ or the module).
- Large requests hanging after enabling = **MTU** (WireGuard adds 60-80 bytes).
- Alternative: IPsec (`encryption.type=ipsec`) with a pre-shared key Secret. Mesh-layer mTLS
  (Istio ambient) is covered in scenarios 29 and 30.
