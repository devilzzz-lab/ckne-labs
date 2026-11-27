# Scenario 01 – Install Cilium as a kube-proxy replacement

**Domain 1 – Core Infrastructure and CNI** · Session: **B (Cilium)** · Time: ~10 min

## Context

This is a freshly built cluster with **no CNI and no kube-proxy** (`setup.sh` removed
Calico and kube-proxy). Nodes are `NotReady` and CoreDNS cannot start.

> ⚠ This changes cluster-wide networking and cannot be undone. **Restart the
> Killercoda playground** afterwards if you want Calico back (needed for the Istio
> scenarios 21, 29, 30).

## Task

Use the **Cilium CLI** (`cilium` is already on the PATH) to install Cilium so that:

1. Cilium **replaces kube-proxy completely** (`kubeProxyReplacement=true`).
2. **eBPF masquerading** is enabled (`bpf.masquerade=true`).
3. The Cilium CLI install uses the **real API server address** (find it from the
   `kubernetes` EndpointSlice in the `default` namespace, port `6443`), because
   without kube-proxy the `kubernetes` ClusterIP does not work yet.
4. Cilium does not rename other CNI config files (`cni.exclusive=false`, needed for
   Multus in scenario 07).

Wait until `cilium status` is healthy and both nodes are `Ready`.

## Test AFTER fix

```bash
cilium status --wait
kubectl get nodes
kubectl -n kube-system exec ds/cilium -- cilium-dbg status | grep -E "KubeProxyReplacement|Masquerading"
```

## Hints

- `cilium install --help`, then `--set key=value` (these are Helm values).
- `kubectl get endpointslices -n default -l kubernetes.io/service-name=kubernetes`
- Docs: <https://docs.cilium.io/en/stable/network/kubernetes/kubeproxy-free/>
