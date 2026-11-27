# Solution – Scenario 18: Cilium BGP Control Plane

## Step 1 – Enable the control plane

```bash
# keep the running version: `cilium upgrade` without --version moves to the CLI's default version
CV=$(kubectl -n kube-system get ds cilium -o jsonpath='{.spec.template.spec.containers[0].image}' | sed -E 's/.*:v?([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
cilium upgrade --version $CV --reuse-values --set bgpControlPlane.enabled=true
kubectl -n kube-system rollout restart ds/cilium deploy/cilium-operator
kubectl -n kube-system rollout status ds/cilium
kubectl api-resources | grep -i ciliumbgp          # CRDs now exist
```

## Step 2 – Label the node and read the router address

```bash
kubectl label node controlplane bgp=enabled
FRR=$(kubectl -n bgp-lab get pod frr-router -o jsonpath='{.status.podIP}')
```

## Step 3 – The three resources

```bash
kubectl apply -f - <<EOF
apiVersion: cilium.io/v2
kind: CiliumBGPClusterConfig
metadata:
  name: cilium-bgp
spec:
  nodeSelector:
    matchLabels:
      bgp: enabled
  bgpInstances:
  - name: instance-65001
    localASN: 65001
    peers:
    - name: frr
      peerASN: 65000
      peerAddress: $FRR
      peerConfigRef:
        name: frr-peer
---
apiVersion: cilium.io/v2
kind: CiliumBGPPeerConfig
metadata:
  name: frr-peer
spec:
  families:
  - afi: ipv4
    safi: unicast
    advertisements:
      matchLabels:
        advertise: bgp
---
apiVersion: cilium.io/v2
kind: CiliumBGPAdvertisement
metadata:
  name: bgp-adv
  labels:
    advertise: bgp
spec:
  advertisements:
  - advertisementType: PodCIDR
  - advertisementType: Service
    service:
      addresses:
      - LoadBalancerIP
    selector:
      matchExpressions:
      - key: somekey
        operator: NotIn
        values: ["never-used-value"]
EOF
```

## Step 4 – Verify

```bash
cilium bgp peers                                   # SESSION STATE: established
cilium bgp routes advertised ipv4 unicast          # the node's pod CIDR
kubectl -n bgp-lab exec frr-router -- vtysh -c 'show bgp summary'
kubectl -n bgp-lab exec frr-router -- vtysh -c 'show ip bgp'
```

## Why / troubleshooting

| Symptom | Cause |
|---------|-------|
| `cilium bgp peers` empty | node not labelled, or `nodeSelector` mismatch |
| `active` / `connect` | wrong `peerAddress`, TCP/179 blocked, or the router has no neighbor for you |
| `established`, but no routes | PeerConfig `advertisements.matchLabels` does not match the Advertisement's `labels` |
| Session flapping / ASN error | `localASN` / `peerASN` swapped |
| Routes present, traffic fails | the router needs a return path and `rp_filter` may drop packets |

Older Cilium used `cilium.io/v2alpha1` and `CiliumBGPPeeringPolicy`. Always match
`kubectl api-resources`. `advertisementType: PodCIDR` only works with Kubernetes or
cluster-pool IPAM (multi-pool needs `CiliumPodIPPool`).
