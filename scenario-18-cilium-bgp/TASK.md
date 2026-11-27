# Scenario 18 – Cilium BGP Control Plane

**Domain 3 – Advanced Traffic Management** · Session: **B (Cilium)** · Time: ~15 min

## Context

An upstream router must learn how to reach this cluster. In the lab the "router" is the
Pod **`frr-router`** (FRRouting) in namespace **`bgp-lab`**. It uses **ASN 65000** and
accepts BGP sessions from ASN **65001**.

```bash
kubectl -n bgp-lab get pod frr-router -o wide        # its Pod IP is the BGP peer address
```

The Cilium BGP Control Plane is **not enabled yet**.

## Task

1. Enable the Cilium BGP Control Plane (`bgpControlPlane.enabled=true`) and restart
   the Cilium agents and operator so that the BGP CRDs appear.
2. Label node **`controlplane`** with **`bgp=enabled`**. Only labelled nodes may speak BGP.
3. Create these resources (name them exactly):
   - **`CiliumBGPClusterConfig` `cilium-bgp`**: node selector `bgp=enabled`, one BGP
     instance with **`localASN: 65001`**, and one peer named **`frr`** with
     **`peerASN: 65000`**, `peerAddress` = the **Pod IP of `frr-router`**, and
     `peerConfigRef` → `frr-peer`.
   - **`CiliumBGPPeerConfig` `frr-peer`**: address family **ipv4 / unicast** whose
     advertisements are selected by the label **`advertise: bgp`**.
   - **`CiliumBGPAdvertisement` `bgp-adv`** with the label `advertise: bgp`, announcing
     **PodCIDR** and **LoadBalancerIP** Service addresses (for **all** Services).

## Test AFTER fix

```bash
cilium bgp peers                                       # session established
cilium bgp routes advertised ipv4 unicast
kubectl -n bgp-lab exec frr-router -- vtysh -c 'show bgp summary'
```

## Hints

- `kubectl api-resources | grep -i ciliumbgp`, then `kubectl explain ciliumbgpclusterconfig.spec`.
- The chain is **ClusterConfig → PeerConfig → Advertisement**, linked by name and label.
- Without a matching Advertisement label the session comes up but **nothing is sent**.
- To match every Service in an advertisement, use a `matchExpressions` selector that is
  always true, for example `key: somekey, operator: NotIn, values: [never-used-value]`.
- Docs: <https://docs.cilium.io/en/stable/network/bgp-control-plane/bgp-control-plane-v2/>
