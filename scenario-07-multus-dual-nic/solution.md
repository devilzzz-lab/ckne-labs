# Solution – Scenario 07: Multi-interface Pod with Multus

```bash
kubectl apply -f - <<'EOF'
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: internal-net
  namespace: net
spec:
  config: |
    {
      "cniVersion": "0.3.1",
      "type": "bridge",
      "bridge": "br-int",
      "ipam": {
        "type": "host-local",
        "subnet": "192.168.50.0/24",
        "rangeStart": "192.168.50.100",
        "rangeEnd": "192.168.50.150"
      }
    }
---
apiVersion: v1
kind: Pod
metadata:
  name: dual-nic
  namespace: net
  annotations:
    k8s.v1.cni.cncf.io/networks: internal-net
spec:
  containers:
  - name: c
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF

kubectl -n net wait --for=condition=Ready pod/dual-nic --timeout=120s
kubectl -n net exec dual-nic -- ip -br addr
#   eth0   UP   10.x.x.x/32 ...        <- primary CNI (Calico / Cilium)
#   net1   UP   192.168.50.100/24      <- Multus + bridge + host-local
kubectl -n net get pod dual-nic \
  -o jsonpath='{.metadata.annotations.k8s\.v1\.cni\.cncf\.io/network-status}'
```

## Why

- Multus is a **meta-plugin**. It calls the primary CNI for `eth0`, then calls every
  plugin named in the Pod's `k8s.v1.cni.cncf.io/networks` annotation for `net1`, `net2`, ...
- The NAD `config` is a normal CNI config. `"type"` must be a binary in `/opt/cni/bin`
  on the node that runs the Pod. If it is missing the Pod stays `ContainerCreating`.
- To use a NAD from another namespace write `namespace/name` in the annotation.
- With Cilium you need `cni.exclusive=false` (scenario 01) or Cilium moves the other CNI
  configs out of the way. Multus then never runs.
- `host-local` IPAM is per node. Two Pods on two nodes can get the same address from the
  same range, so use `whereabouts` for cluster-wide IPAM in real setups.
