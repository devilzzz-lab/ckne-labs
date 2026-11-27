# Domain 3: Advanced Traffic Management (20%)

Official competencies:
1. Optimizing LLM traffic
2. Implementing routing to expose networks
3. Configuring egress gateways for cluster exit traffic
4. Implementing cross-cluster service discovery and load balancing

Labs: **17** InferencePool · **18** Cilium BGP · **19** Cilium egress gateway ·
**20** Cluster Mesh repair · **21** Istio registry-only egress

Tasks here have several layers (Helm value, CRD, node label). A mistake in one hides behind another, so
read the whole task and verify each layer before the next.

---

## 1. Optimizing LLM traffic: Gateway API Inference Extension  (lab 17)

Round-robin is a poor fit for LLM servers: requests differ hugely in cost and every replica has its own queue,
KV-cache and loaded LoRA adapters. The extension adds an **Endpoint Picker (EPP)** that the gateway asks for
every request. The EPP picks the best model-server Pod from live metrics.

```text
client -POST /v1/completions-> Gateway -> HTTPRoute -> InferencePool -(ask EPP)-> best model-server Pod
```

| Resource | Purpose |
|----------|---------|
| `InferencePool` | the model-server Pods (label selector + target port) and a reference to the EPP. An HTTPRoute uses it **as a backend instead of a Service** |
| EPP (Deployment + Service) | scores endpoints (queue depth, KV-cache use, adapters) |
| `InferenceObjective` | optional priority per request class (experimental API group) |

```yaml
apiVersion: inference.networking.k8s.io/v1      # GA. Early releases: inference.networking.x-k8s.io/v1alpha2
kind: InferencePool
metadata: {name: llama-pool, namespace: inference}
spec:
  selector: {matchLabels: {app: vllm-llama}}
  targetPorts: [{number: 8000}]
  endpointPickerRef: {name: llama-epp, port: {number: 9002}}   # failureMode: FailClose (default) | FailOpen
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: {name: llm-route, namespace: inference}
spec:
  parentRefs: [{name: inference-gw}]
  rules:
  - matches: [{path: {type: PathPrefix, value: /v1/completions}, method: POST}]
    backendRefs: [{group: inference.networking.k8s.io, kind: InferencePool, name: llama-pool}]
```

**Always check the served API version:** `kubectl api-resources | grep -i inference`,
`kubectl explain inferencepool.spec --recursive`.

| Symptom | Check |
|---------|-------|
| 404 | path/method does not match, or route not attached (`Accepted=False`) |
| 500/503 at once | EPP down or `endpointPickerRef` wrong (with `FailClose`) |
| `ResolvedRefs=False` | wrong `group`/`kind`/`name`, or the gateway does not support InferencePool |
| wrong Pods | `selector` or `targetPorts` do not match the model servers |

Verify: `kubectl get inferencepool -o yaml`, `kubectl describe httproute`, send
`curl $GW_IP/v1/completions -d '{"model":"...","prompt":"hi","max_tokens":20}'`, then check which Pod served it.

Docs: [Gateway API Inference Extension](https://gateway-api-inference-extension.sigs.k8s.io/) ·
[InferencePool](https://gateway-api-inference-extension.sigs.k8s.io/api-types/inferencepool/) ·
[Releases](https://github.com/kubernetes-sigs/gateway-api-inference-extension/releases)

---

## 2. Routing to expose networks: BGP  (lab 18)

BGP tells an upstream router "send traffic for these prefixes to me". You can advertise **Pod CIDRs** (reach
Pods without NAT) and **Service IPs** (LoadBalancer, ClusterIP, externalIPs).

Enable, then **restart** so the CRDs appear:

```bash
cilium upgrade --version <running-version> --reuse-values --set bgpControlPlane.enabled=true
kubectl -n kube-system rollout restart ds/cilium deploy/cilium-operator
kubectl api-resources | grep -i ciliumbgp
kubectl label node <node> bgp=enabled                       # only labelled nodes speak BGP
```

The chain is **ClusterConfig → PeerConfig → Advertisement**:

```yaml
apiVersion: cilium.io/v2
kind: CiliumBGPClusterConfig
metadata: {name: cilium-bgp}
spec:
  nodeSelector: {matchLabels: {bgp: enabled}}
  bgpInstances:
  - name: instance-65001
    localASN: 65001
    peers:
    - {name: tor, peerASN: 65000, peerAddress: 172.18.0.100, peerConfigRef: {name: tor-peer}}
---
apiVersion: cilium.io/v2
kind: CiliumBGPPeerConfig
metadata: {name: tor-peer}
spec:
  timers: {holdTimeSeconds: 9, keepAliveTimeSeconds: 3}
  families:
  - afi: ipv4
    safi: unicast
    advertisements: {matchLabels: {advertise: bgp}}         # picks Advertisements by LABEL
---
apiVersion: cilium.io/v2
kind: CiliumBGPAdvertisement
metadata: {name: bgp-adv, labels: {advertise: bgp}}
spec:
  advertisements:
  - advertisementType: PodCIDR
  - advertisementType: Service
    service: {addresses: [LoadBalancerIP]}
    selector: {matchExpressions: [{key: somekey, operator: NotIn, values: [never-used-value]}]}   # = all Services
```

| Session / symptom | Likely cause |
|-------------------|--------------|
| `active`, `connect`, `idle` | wrong `peerAddress`, TCP 179 blocked, router has no neighbor for you |
| `established`, no routes | Advertisement labels ≠ PeerConfig `advertisements.matchLabels` (**the classic one**), or Service selector matches nothing |
| ASN error | `localASN` / `peerASN` swapped |
| routes ok, traffic fails | return path / `rp_filter` |
| no BGP at all | node not labelled, `bgpControlPlane` not enabled or agents not restarted |

```bash
cilium bgp peers
cilium bgp routes advertised ipv4 unicast
cilium bgp routes available ipv4 unicast
kubectl get ciliumbgpnodeconfigs -o yaml
vtysh -c "show bgp summary"            # on an FRR router
```

`PodCIDR` works with Kubernetes or cluster-pool IPAM (multi-pool: `CiliumPodIPPool`). Older releases use
`cilium.io/v2alpha1` and `CiliumBGPPeeringPolicy`. Match `kubectl api-resources`. Other BGP speakers:
MetalLB BGP mode (LoadBalancer IPs) and kube-router (Pod CIDRs + Service IPs, inspect with `gobgp`).

Docs: [Cilium BGP Control Plane](https://docs.cilium.io/en/stable/network/bgp-control-plane/bgp-control-plane-v2/) ·
[Troubleshooting BGP](https://docs.cilium.io/en/stable/network/bgp-control-plane/bgp-control-plane-operation/)

---

## 3. Egress gateways  (labs 19, 21)

By default a Pod's external traffic leaves from its node and is SNATed to that **node's IP**, which changes as the
Pod moves. An egress gateway sends selected traffic through chosen nodes and SNATs it to a **fixed IP**, so
firewalls and partners can allow-list one address.

### Cilium Egress Gateway (lab 19)

Prerequisites: `egressGateway.enabled=true`, `bpf.masquerade=true`, `kubeProxyReplacement=true`, then
**restart agents and operator**. When you change values with `cilium upgrade`, pass `--version <running version>`
so Cilium is not upgraded at the same time.

```yaml
apiVersion: cilium.io/v2
kind: CiliumEgressGatewayPolicy
metadata: {name: billing-egress}
spec:
  selectors:
  - podSelector:
      matchLabels: {app: billing, io.kubernetes.pod.namespace: payments}
  destinationCIDRs: [203.0.113.0/24]
  excludedCIDRs: [203.0.113.10/32]
  egressGateway:
    nodeSelector: {matchLabels: {egress-gw: "true"}}
    egressIP: 172.18.0.50          # must be configured on the gateway node (or use `interface:`)
```

The policy is cluster-scoped: limit it to one namespace with `io.kubernetes.pod.namespace` or `namespaceSelector`.

```bash
kubectl -n kube-system exec ds/cilium -- cilium-dbg bpf egress list
#  Source IP   Destination CIDR   Egress IP   Gateway IP
```

| Symptom | Check |
|---------|-------|
| empty `bpf egress list` | feature not enabled, or agents not restarted |
| still the node IP | Pod labels / namespace selector / destination CIDR do not match |
| dropped | `egressIP` is not on the gateway node |
| gateway IP `0.0.0.0` | no node matches the `nodeSelector` |

Docs: [Cilium Egress Gateway](https://docs.cilium.io/en/stable/network/egress-gateway/egress-gateway/)

### Istio egress control and Egress Gateway (lab 21)

- Default `outboundTrafficPolicy` is `ALLOW_ANY`. `REGISTRY_ONLY` sends unknown hosts to the `BlackHoleCluster`
  (HTTP **502**).
- A **`ServiceEntry`** registers an external host (`location: MESH_EXTERNAL`, `resolution: DNS`).
- An **egress gateway** is an Envoy at the mesh edge: sidecars send external traffic to it
  (`Gateway` + `VirtualService` + `DestinationRule`), and a NetworkPolicy lets only the gateway Pods leave. One audited
  exit point.
- This behaviour is **sidecar mode**. Ambient has its own egress options (waypoints / egress gateways).

Docs: [Egress control](https://istio.io/latest/docs/tasks/traffic-management/egress/egress-control/) ·
[Egress gateways](https://istio.io/latest/docs/tasks/traffic-management/egress/egress-gateway/) ·
[ServiceEntry](https://istio.io/latest/docs/reference/config/networking/service-entry/) ·
[Sidecar](https://istio.io/latest/docs/reference/config/networking/sidecar/)

---

## 4. Cross-cluster service discovery: Cilium Cluster Mesh  (lab 20)

Cluster Mesh joins the Cilium datapaths of several clusters. Pods reach Pods across clusters, policies can select
remote identities, and **global services** load-balance across clusters.

| Requirement | Why |
|-------------|-----|
| unique `cluster.name` and `cluster.id` (1-255) | identities and IPs would collide |
| non-overlapping Pod CIDRs | traffic must be routable |
| nodes (and the clustermesh-apiserver) reachable between clusters | data plane and control plane |
| **shared Cilium CA** | the clustermesh components use mutual TLS |

```bash
cilium install --context kind-c1 --set cluster.name=c1 --set cluster.id=1 \
  --set ipam.operator.clusterPoolIPv4PodCIDRList=10.1.0.0/16
kubectl --context kind-c1 -n kube-system get secret cilium-ca -o yaml | kubectl --context kind-c2 create -f -
cilium install --context kind-c2 --set cluster.name=c2 --set cluster.id=2 \
  --set ipam.operator.clusterPoolIPv4PodCIDRList=10.2.0.0/16
cilium clustermesh enable --context kind-c1 --service-type LoadBalancer
cilium clustermesh enable --context kind-c2 --service-type LoadBalancer
cilium clustermesh status --context kind-c1 --wait
cilium clustermesh connect --context kind-c1 --destination-context kind-c2
```

**Global service:** a Service with the **same name and namespace** in each cluster, with annotations:

```yaml
metadata:
  annotations:
    service.cilium.io/global: "true"     # merge backends across clusters
    service.cilium.io/shared: "true"     # (default true) share this cluster's backends with others
    service.cilium.io/affinity: "local"  # prefer local backends; "remote" or "none" also exist
```

A client in c1 can reach a backend that only runs in c2: the Service object must exist in **both** clusters (the c1
one may select nothing).

| Symptom | Cause |
|---------|-------|
| 0 remote nodes | clustermesh-apiserver unreachable (no LB IP, firewall) or not enabled |
| TLS/certificate errors | CA not shared |
| duplicate cluster id | same `cluster.id` twice |
| only local backends hit | annotation missing in one cluster, or `affinity: local` with healthy local backends |
| cross-cluster Pod traffic dropped | overlapping CIDRs, or a policy missing the remote identity |

```bash
cilium clustermesh status
kubectl -n kube-system exec ds/cilium -- cilium-dbg troubleshoot clustermesh
kubectl -n kube-system exec ds/cilium -- cilium-dbg service list
```

Newer Cilium also supports the Kubernetes **Multi-Cluster Services API** (`ServiceExport` / `ServiceImport`,
`*.svc.clusterset.local`). Istio multicluster is the mesh-level alternative.

Docs: [Cluster Mesh setup](https://docs.cilium.io/en/stable/network/clustermesh/clustermesh/) ·
[Global services](https://docs.cilium.io/en/stable/network/clustermesh/services/) ·
[Istio multicluster](https://istio.io/latest/docs/setup/install/multicluster/) ·
[MCS API](https://github.com/kubernetes-sigs/mcs-api)

---

## Checklist

- [ ] Explain why inference traffic needs an endpoint picker, and write an InferencePool + HTTPRoute
- [ ] Enable Cilium BGP and peer with a router, advertising Pod CIDRs and LoadBalancer IPs
- [ ] Fix a BGP setup with a wrong peer IP or a missing/unmatched Advertisement label
- [ ] Send one app's external traffic out of a chosen node with a fixed source IP, and prove it with `bpf egress list`
- [ ] Block unknown external hosts in an Istio namespace and allow one with a ServiceEntry
- [ ] List the Cluster Mesh prerequisites and the exact commands to join two clusters
- [ ] Make a Service global and explain `affinity`
