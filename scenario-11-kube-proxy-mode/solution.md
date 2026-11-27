# Solution – Scenario 11: Which proxy programs the Services?

## Step 1 – Who is the implementation?

```bash
kubectl -n kube-system get ds kube-proxy            # exists?  -> kube-proxy
kubectl -n kube-system get cm kube-proxy -o yaml | grep -E '^\s+mode:'
#   mode: ""   (empty = iptables, the default)  /  ipvs  /  nftables
kubectl -n kube-system get ds cilium                # Cilium KPR if there is no kube-proxy
kubectl -n kube-system exec ds/cilium -- cilium-dbg status | grep KubeProxyReplacement
```

```bash
# examples
echo iptables > /opt/answers/proxy-impl.txt     # Session A (Calico + kube-proxy)
echo cilium   > /opt/answers/proxy-impl.txt     # Session B (after scenario 01)
```

## Step 2 – ClusterIP

```bash
kubectl -n px get svc web -o jsonpath='{.spec.clusterIP}' > /opt/answers/web-clusterip.txt
```

## Step 3 – Backends as the dataplane sees them

**kube-proxy iptables mode**

```bash
CIP=$(cat /opt/answers/web-clusterip.txt)
iptables-save -t nat | grep "$CIP"                          # jump to KUBE-SVC-XXXX
iptables-save -t nat | grep 'KUBE-SVC-XXXX'                 # 3 jumps to KUBE-SEP-*, with probabilities
iptables-save -t nat | grep -E 'KUBE-SEP-.*DNAT'            # --to-destination <podIP>:80
```

**ipvs:** `ipvsadm -Ln | grep -A4 $CIP`  **nftables:** `nft list table ip kube-proxy | grep $CIP`

**Cilium KPR**

```bash
kubectl -n kube-system exec ds/cilium -- cilium-dbg service list | grep -A3 "$CIP:80"
```

Write them sorted, one per line:

```bash
kubectl -n px get endpointslices -l kubernetes.io/service-name=web \
  -o jsonpath='{range .items[*].endpoints[*]}{.addresses[0]}{"\n"}{end}' | sed 's/$/:80/' | sort > /opt/answers/web-backends.txt
```

## Why

| Implementation | Rules live in | Inspect with |
|----------------|---------------|--------------|
| kube-proxy iptables | `KUBE-SERVICES` → `KUBE-SVC-*` → `KUBE-SEP-*` NAT chains | `iptables-save -t nat` |
| kube-proxy ipvs | IPVS virtual servers on `kube-ipvs0` (deprecated) | `ipvsadm -Ln` |
| kube-proxy nftables | nftables table `kube-proxy` | `nft list ruleset` |
| Cilium KPR | eBPF maps, no iptables rules for Services | `cilium-dbg service list` |
| kube-router | IPVS + gobgp + ipset | `ipvsadm -Ln`, `gobgp neighbor` |
