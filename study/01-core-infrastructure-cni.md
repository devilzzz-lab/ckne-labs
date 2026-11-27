# Domain 1: Core Infrastructure and CNI (15%)

Official competencies:
1. Installing and configuring CNI plugins
2. Managing IPAM and Pod CIDR allocation
3. Using Linux tools (`iptables`, `ip`, `tcpdump`) for packet-level issues
4. Troubleshooting Pod connectivity (DNS, pod-to-pod)
5. Configuring multi-interface Pods

Labs: **01** install Cilium · **02** IPAM · **03** tcpdump · **04** iptables · **05** tc netem ·
**06** Pod DNS · **07** Multus

---

## 1. What a CNI plugin does

When the kubelet starts a Pod, the container runtime creates the network namespace and calls the
CNI plugin binary with `ADD`. The plugin creates an interface (usually a veth pair), asks IPAM
for an address, sets routes, and returns the result. On delete the runtime calls `DEL`.

| Location (every node) | Content |
|-----------------------|---------|
| `/etc/cni/net.d/` | CNI configs. The runtime uses the **first file in lexical order** |
| `/opt/cni/bin/` | plugin binaries (`cilium-cni`, `bridge`, `host-local`, `macvlan`, ...) |

- Nodes stay `NotReady` until a CNI config exists.
- A leftover config that sorts first (e.g. `10-flannel.conflist`) wins over the one you want. If Pods get
  IPs from the wrong range, look here first.
- Calico and Cilium both enforce NetworkPolicy. **Flannel does not.**

Docs: [CNI spec](https://github.com/containernetworking/cni/blob/main/SPEC.md) ·
[Cilium](https://docs.cilium.io/) · [Calico](https://docs.tigera.io/calico/latest/about/)

---

## 2. Installing Cilium with the CLI  (lab 01)

```bash
cilium install --set kubeProxyReplacement=true \
               --set k8sServiceHost=<API-IP> --set k8sServicePort=6443 \
               --set bpf.masquerade=true
cilium status --wait
cilium connectivity test            # optional end-to-end test (creates namespace cilium-test-1)
```

`--set key=value` takes **Helm values** ([Helm reference](https://docs.cilium.io/en/stable/helm-reference/)).
Inspect the result:

```bash
cilium config view                               # the cilium-config ConfigMap
helm get values cilium -n kube-system
kubectl -n kube-system exec ds/cilium -- cilium-dbg status --verbose
```

Change a running install, then **restart**, because agents only read config at start:

```bash
cilium upgrade --version <running-version> --reuse-values --set <key>=<value>   # pin the version, see `cilium version`
kubectl -n kube-system rollout restart ds/cilium deploy/cilium-operator
```

### kube-proxy replacement (KPR) and BPF masquerading

| Feature | What it does | Value |
|---------|--------------|-------|
| KPR | Cilium handles ClusterIP/NodePort/LoadBalancer/externalIPs in eBPF. No `KUBE-SVC-*` chains | `kubeProxyReplacement=true` |
| API server address | Without kube-proxy the `kubernetes` ClusterIP does not work yet, so Cilium needs the real address | `k8sServiceHost`, `k8sServicePort` |
| BPF masquerade | SNAT for traffic leaving the cluster done in eBPF instead of iptables | `bpf.masquerade=true` |
| Share the node with Multus / Istio CNI | Do not rename other CNI configs | `cni.exclusive=false` |

Verify: `cilium-dbg status | grep -E "KubeProxyReplacement|Masquerading"` → `True`, `BPF`.

Masquerading **does not** apply to traffic to the local node's Pod CIDR, to `ipv4NativeRoutingCIDR` (if set),
and (in eBPF mode) to other cluster nodes.

If the cluster still has kube-proxy: delete the DaemonSet and ConfigMap and flush its iptables rules, or
on a new kubeadm cluster skip it: `kubeadm init --skip-phases=addon/kube-proxy`.

Docs: [Kubernetes without kube-proxy](https://docs.cilium.io/en/stable/network/kubernetes/kubeproxy-free/) ·
[Masquerading](https://docs.cilium.io/en/stable/network/concepts/masquerading/)

---

## 3. IPAM and Pod CIDR  (lab 02)

| Where | Source of the Pod CIDR |
|-------|------------------------|
| Cluster | `kube-controller-manager --cluster-cidr` + `--allocate-node-cidrs=true` (kubeadm `networking.podSubnet`) |
| Node | `node.spec.podCIDR(s)` |
| Cilium `ipam.mode=kubernetes` | uses `node.spec.podCIDR` |
| Cilium `ipam.mode=cluster-pool` | operator carves per-node CIDRs from `ipam.operator.clusterPoolIPv4PodCIDRList` (`clusterPoolIPv4MaskSize` per node) |
| Cilium `ipam.mode=multi-pool` | several `CiliumPodIPPool` objects |

```bash
kubectl get nodes -o custom-columns=NAME:.metadata.name,PODCIDR:.spec.podCIDR
kubectl get ciliumnodes -o custom-columns=NAME:.metadata.name,CIDRS:.spec.ipam.podCIDRs
cilium config view | grep -i ipam
```

Rules: the Pod CIDR must not overlap the node network, the Service CIDR, or (Cluster Mesh) another
cluster. Do not edit existing `clusterPoolIPv4PodCIDRList` entries after install (add new ones). You cannot change
`clusterPoolIPv4MaskSize` or the IPAM mode of a live cluster. `ContainerCreating` + IP allocation errors =
the node's pool is exhausted.

Docs: [Cilium IPAM](https://docs.cilium.io/en/stable/network/concepts/ipam/) ·
[Calico IPAM](https://docs.tigera.io/calico/latest/networking/ipam/get-started-ip-addresses)

---

## 4. Linux tools for packet-level problems  (labs 03, 04, 05)

### `ip`, `ss`

```bash
ip -br addr; ip route; ip route get <ip>; ip neigh; ip -d link show <dev>
ss -lntp                              # who listens
```

### Get into a Pod's network namespace from the node

```bash
PID=$(crictl inspect $(crictl ps --name <ctr> -q) | jq .info.pid)
nsenter -t $PID -n ip addr
nsenter -t $PID -n tcpdump -i eth0 -nn
kubectl debug -it <pod> --image=nicolaka/netshoot --target=<container>     # alternative
```

### `tcpdump`  (lab 03)

| Need | Command |
|------|---------|
| Port on an interface | `tcpdump -i eth0 -nn port 8080` |
| Exact packet count | `tcpdump -i any -nn -c 25 dst port 8080` |
| Save / read | `tcpdump -nn -c 100 -w /tmp/c.pcap port 80` / `tcpdump -nn -r /tmp/c.pcap` |
| One host and port | `tcpdump -i any -nn host 10.0.1.5 and tcp port 8080` |
| SYNs only | `tcpdump -nn 'tcp[tcpflags] & (tcp-syn|tcp-ack) == tcp-syn'` |
| DNS | `tcpdump -i any -nn udp port 53` |
| Payload | `-A` |

Always `-nn`. Use **exactly** the count, path and interface the task names.

### `iptables`  (lab 04)

```bash
iptables -t nat -L -n -v --line-numbers
iptables-save | grep <ip-or-port>
iptables -D INPUT <line>                  # delete one rule by number
sysctl net.ipv4.ip_forward                # must be 1 on nodes that forward Pod traffic
```

Reading NAT: `PREROUTING → KUBE-SERVICES → KUBE-SVC-x → KUBE-SEP-x (DNAT to podIP:port)`;
`POSTROUTING` has MASQUERADE/SNAT. Rules match **top to bottom**, so a manual rule above the Kubernetes
chain wins. A `DROP` with growing counters is your culprit. Never `iptables -F` on a node.

### Latency  (lab 05)

```bash
curl -o /dev/null -s -w 'dns:%{time_namelookup} connect:%{time_connect} ttfb:%{time_starttransfer} total:%{time_total}\n' URL
tc qdisc show dev eth0               # netem delay/loss
tc qdisc del dev eth0 root           # remove it
ss -tni; ethtool -S eth0 | grep -i drop
```

---

## 5. Troubleshooting Pod connectivity  (lab 06)

Go bottom-up and change **one** thing at a time:

```text
1 Pod has IP and Ready?          kubectl get pod -o wide
2 same-node Pod to Pod?          kubectl exec a -- curl -m3 <podB-ip>:<port>
3 cross-node Pod to Pod?         tunnel / routing / MTU / encryption
4 Pod to Service ClusterIP?      translation, endpoints
5 DNS resolves the name?         nslookup <svc>.<ns>.svc.cluster.local
6 Pod to external?               masquerade, egress policy, routes
7 a policy dropping it?          hubble observe --verdict DROPPED
```

DNS symptom table:

| Symptom | Likely cause |
|---------|--------------|
| cluster names fail, IPs work | CoreDNS down, kube-dns has no endpoints, policy blocks 53 |
| cluster names work, external fail | `forward` target wrong/unreachable (Domain 2) |
| intermittent timeouts | one bad CoreDNS replica, conntrack, MTU |
| only the **Pod** fails | its `dnsPolicy`/`dnsConfig` (lab 06): `None` or `Default` skips cluster DNS |
| large responses fail | MTU (tunnel or WireGuard overhead) |

`dnsPolicy`: `ClusterFirst` (default), `Default` (node resolver only), `None` (use `dnsConfig` only),
`ClusterFirstWithHostNet` (for `hostNetwork: true`).

Cilium views: `cilium-dbg endpoint list`, `cilium-dbg status --all-health`, `cilium-dbg monitor --type drop`.

Docs: [Debugging DNS resolution](https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/) ·
[Pod DNS policy](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/#pod-s-dns-policy) ·
[Debug Pods](https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/)

---

## 6. Multi-interface Pods with Multus  (lab 07)

Multus is a **meta-plugin**: the primary CNI still gives `eth0`, Multus adds `net1`, `net2`, ... defined by
`NetworkAttachmentDefinition` (NAD) objects.

```yaml
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata: {name: internal-net, namespace: net}
spec:
  config: |
    {"cniVersion":"0.3.1","type":"bridge","bridge":"br-int",
     "ipam":{"type":"host-local","subnet":"192.168.50.0/24"}}
---
apiVersion: v1
kind: Pod
metadata:
  name: dual-nic
  annotations: {k8s.v1.cni.cncf.io/networks: internal-net}   # ns/name for another namespace
```

- `"type"` must exist in `/opt/cni/bin` on the node, or the Pod sticks in `ContainerCreating`.
- With Cilium: `cni.exclusive=false`, or Cilium moves other CNI configs out of the way.
- Verify: `kubectl exec dual-nic -- ip -br addr` and the annotation
  `k8s.v1.cni.cncf.io/network-status`.
- Per-node `host-local` IPAM can hand out duplicate addresses on different nodes. `whereabouts` is cluster-wide.

Docs: [Multus quickstart](https://github.com/k8snetworkplumbingwg/multus-cni/blob/master/docs/quickstart.md) ·
[bridge plugin](https://www.cni.dev/plugins/current/main/bridge/) ·
[macvlan plugin](https://www.cni.dev/plugins/current/main/macvlan/)

---

## Checklist

- [ ] Install Cilium with the CLI, KPR on, BPF masquerade on, and prove it from the agent status
- [ ] Explain which traffic is and is not masqueraded
- [ ] Read a node's Pod CIDR from the Node and from the CiliumNode
- [ ] Capture N packets on a given interface/port to a pcap and read it back
- [ ] Find and delete one iptables rule without touching others
- [ ] Spot and remove `tc netem` delay
- [ ] Debug a Pod that cannot resolve cluster names (resolv.conf, dnsPolicy, CoreDNS)
- [ ] Attach a second interface to a Pod with Multus
