# Scenario 02 – IPAM and Pod CIDR investigation

**Domain 1 – Core Infrastructure and CNI** · Session: **B (Cilium)** · Time: ~6 min

## Context

Cilium is the CNI. A teammate needs to know where Pod IPs in this cluster come from
before they plan a Cluster Mesh. Nothing is broken. You only need to read the facts.

## Task

Write each answer as a **single value on one line** into the file shown:

| File | Content |
|------|---------|
| `/opt/answers/ipam-mode.txt` | The IPAM mode Cilium is using (for example `kubernetes` or `cluster-pool`) |
| `/opt/answers/cluster-cidr.txt` | The cluster-wide pod CIDR that `kube-controller-manager` is started with (`--cluster-cidr`) |
| `/opt/answers/node01-podcidr.txt` | The pod CIDR that Cilium has allocated to node `node01` (from its `CiliumNode`) |
| `/opt/answers/node01-cidr-source.txt` | Which object the CIDR comes from: `node` if Cilium copies `node.spec.podCIDR`, `operator` if the Cilium operator carves it from a pool |

## Test AFTER fix

```bash
cat /opt/answers/*.txt
```

## Hints

- `cilium config view | grep -i ipam`
- `kubectl get ciliumnodes -o custom-columns=NAME:.metadata.name,CIDRS:.spec.ipam.podCIDRs`
- `kubectl get node node01 -o jsonpath='{.spec.podCIDR}'`
- The controller-manager manifest is `/etc/kubernetes/manifests/kube-controller-manager.yaml`.
- Docs: <https://docs.cilium.io/en/stable/network/concepts/ipam/>
