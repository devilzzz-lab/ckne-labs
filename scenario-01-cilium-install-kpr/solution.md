# Solution – Scenario 01: Install Cilium as a kube-proxy replacement

## Step 1 – Find the API server address

```bash
API=$(kubectl get endpointslices -n default -l kubernetes.io/service-name=kubernetes \
  -o jsonpath='{.items[0].endpoints[0].addresses[0]}')
echo $API
```

## Step 2 – Install

```bash
cilium install \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost=$API \
  --set k8sServicePort=6443 \
  --set bpf.masquerade=true \
  --set cni.exclusive=false

cilium status --wait
```

## Step 3 – Verify

```bash
kubectl get nodes
kubectl -n kube-system exec ds/cilium -- cilium-dbg status | grep -E "KubeProxyReplacement|Masquerading"
#   KubeProxyReplacement:   True   [...]
#   Masquerading:           BPF    [...]
kubectl -n kube-system exec ds/cilium -- cilium-dbg service list | head
```

## Why

- Without kube-proxy nobody translates the `kubernetes` ClusterIP, so Cilium must be
  told the real API server IP and port (`k8sServiceHost` / `k8sServicePort`).
- `bpf.masquerade=true` makes Cilium SNAT pod traffic that leaves the cluster in eBPF
  instead of iptables. The egress gateway (scenario 19) requires it together with KPR.
- `cni.exclusive=false` stops Cilium renaming other CNI configs in `/etc/cni/net.d/`,
  which would break Multus.
- Every `--set` key is a Helm value: <https://docs.cilium.io/en/stable/helm-reference/>
