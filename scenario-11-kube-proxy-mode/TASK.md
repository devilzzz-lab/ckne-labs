# Scenario 11 – Which proxy programs the Services?

**Domain 2 – Service Networking and DNS** · Session: A or B · Time: ~8 min

## Context

Before you debug a Service you must know **what implements it** on the nodes:
kube-proxy (iptables, ipvs or nftables mode) or a CNI such as Cilium running as a
kube-proxy replacement. Namespace `px` has Deployment `web` (3 replicas) and a
ClusterIP Service `web` on port 80.

## Task

Write these answers (one value per line) into the files below.

| File | Content |
|------|---------|
| `/opt/answers/proxy-impl.txt` | The implementation that programs Services: `iptables`, `ipvs`, `nftables` or `cilium` |
| `/opt/answers/web-clusterip.txt` | The ClusterIP of Service `web` |
| `/opt/answers/web-backends.txt` | The backends of `web` as `podIP:port`, **one per line**, sorted, as the dataplane sees them (3 lines) |

To prove it is the dataplane view and not just the API, **find the backends on a node**:
in the iptables NAT rules, in `ipvsadm`, in `nft`, or in the Cilium service table.

## Test AFTER fix

```bash
cat /opt/answers/proxy-impl.txt /opt/answers/web-clusterip.txt /opt/answers/web-backends.txt
```

## Hints

- kube-proxy: `kubectl -n kube-system get cm kube-proxy -o yaml | grep mode`
- iptables: `iptables-save -t nat | grep <clusterIP>` then follow the `KUBE-SVC-*` → `KUBE-SEP-*` chains
- Cilium: `kubectl -n kube-system exec ds/cilium -- cilium-dbg service list`
- Docs: <https://kubernetes.io/docs/reference/networking/virtual-ips/> and
  <https://docs.cilium.io/en/stable/network/kubernetes/kubeproxy-free/>
