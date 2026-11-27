# Solution – Scenario 02: IPAM and Pod CIDR investigation

```bash
mkdir -p /opt/answers

# 1. Cilium IPAM mode
cilium config view | grep -E '^ipam\s'
cilium config view | awk '$1=="ipam"{print $2}' > /opt/answers/ipam-mode.txt

# 2. Cluster-wide pod CIDR the controller-manager hands out
grep -- --cluster-cidr /etc/kubernetes/manifests/kube-controller-manager.yaml
grep -- --cluster-cidr /etc/kubernetes/manifests/kube-controller-manager.yaml | sed 's/.*=//' > /opt/answers/cluster-cidr.txt

# 3. CIDR Cilium gave node01
kubectl get ciliumnode node01 -o jsonpath='{.spec.ipam.podCIDRs[0]}' > /opt/answers/node01-podcidr.txt

# 4. Source of the CIDR
#   ipam=kubernetes   -> node
#   ipam=cluster-pool -> operator
echo node > /opt/answers/node01-cidr-source.txt     # use "operator" for cluster-pool
```

## Why

| IPAM mode | Where the node's pod CIDR comes from |
|-----------|--------------------------------------|
| `kubernetes` | `node.spec.podCIDR`, assigned by kube-controller-manager from `--cluster-cidr` (needs `--allocate-node-cidrs=true`) |
| `cluster-pool` | Cilium operator, from `ipam.operator.clusterPoolIPv4PodCIDRList` with `clusterPoolIPv4MaskSize` per node |
| `multi-pool` | `CiliumPodIPPool` objects selected per namespace/pod |

`cilium install` on a kubeadm cluster usually detects `--allocate-node-cidrs` and picks
`kubernetes`. Pod CIDRs must never overlap the node network, the Service CIDR, or (for
Cluster Mesh) another cluster's pod CIDR.
