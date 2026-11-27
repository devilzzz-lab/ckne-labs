# Domain 2: Service Networking and DNS (25%)

Official competencies:
1. Configuring L4 Services
2. Understanding kube-proxy and CNI alternatives
3. Customizing CoreDNS for Services
4. Troubleshooting Service network traffic
5. Configuring Pod endpoint availability
6. Managing traffic with the Gateway API (Gateway, HTTPRoutes)

Labs: **08** service types · **09** selectorless Service · **10** MetalLB · **11** which proxy ·
**12** CoreDNS corp zone · **13** CoreDNS external · **14** no endpoints · **15** Gateway routing ·
**16** Gateway troubleshooting

---

## 1. L4 Services  (labs 08, 09, 10)

| Type | Reachable from | Notes |
|------|----------------|-------|
| `ClusterIP` | inside the cluster | default |
| `NodePort` | `<nodeIP>:30000-32767` | ClusterIP + a port on every node |
| `LoadBalancer` | external IP from a LB implementation (cloud, MetalLB, Cilium LB-IPAM) | NodePort + LB |
| `ExternalName` | DNS CNAME only | no proxying, no endpoints, no port mapping |
| Headless `clusterIP: None` | DNS returns Pod IPs | StatefulSets, client-side LB |

```yaml
spec:
  type: LoadBalancer
  selector: {app: web}
  ports: [{name: http, port: 80, targetPort: 8080}]    # port = Service, targetPort = container
  externalTrafficPolicy: Local          # keep client IP; nodes without a local endpoint get no traffic
  internalTrafficPolicy: Local          # in-cluster clients only reach endpoints on their own node
  sessionAffinity: ClientIP
  trafficDistribution: PreferClose      # hint: prefer same zone (topology)
```

| Field | Effect |
|-------|--------|
| `externalTrafficPolicy: Cluster` | any node forwards, but source IP is SNATed |
| `externalTrafficPolicy: Local` | source IP preserved, only nodes with a local endpoint answer health checks |
| `internalTrafficPolicy: Local` | traffic dropped if the node has no local endpoint |
| `trafficDistribution: PreferClose` / `PreferSameZone` / `PreferSameNode` | prefer closer endpoints, never a hard rule |

### Service **without** a selector + EndpointSlice  (lab 09; reported in the beta)

```yaml
apiVersion: v1
kind: Service
metadata: {name: external-api}
spec:
  ports: [{name: http, port: 80, targetPort: 8088}]      # NO selector
---
apiVersion: discovery.k8s.io/v1
kind: EndpointSlice
metadata:
  name: external-api-1
  labels: {kubernetes.io/service-name: external-api}     # the link to the Service
addressType: IPv4
ports: [{name: http, port: 8088, protocol: TCP}]         # same port NAME as the Service
endpoints:
- addresses: ["192.0.2.10"]
```

Key details: **missing selector**, **`kubernetes.io/service-name` label**, **explicit address**, matching port name.
For a DNS name use `type: ExternalName`.

### MetalLB  (lab 10)

On bare metal / kind a `LoadBalancer` stays `<pending>` until something hands out IPs.

```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata: {name: lab-pool, namespace: metallb-system}
spec: {addresses: ["172.30.255.200-172.30.255.220"]}
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata: {name: lab-l2, namespace: metallb-system}
spec: {ipAddressPools: [lab-pool]}
```

Controller assigns, speaker announces (L2 = ARP, or BGP with `BGPPeer`/`BGPAdvertisement`). Debug:
`kubectl -n metallb-system logs deploy/controller` and `logs -l component=speaker`.
Cilium can do it natively (`CiliumLoadBalancerIPPool`), so do not run two allocators.

Docs: [Service](https://kubernetes.io/docs/concepts/services-networking/service/) ·
[Services without selectors](https://kubernetes.io/docs/concepts/services-networking/service/#services-without-selectors) ·
[EndpointSlices](https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/) ·
[Connecting applications with Services](https://kubernetes.io/docs/tutorials/services/connect-applications-service/) ·
[Topology aware routing](https://kubernetes.io/docs/concepts/services-networking/topology-aware-routing/) ·
[MetalLB](https://metallb.io/configuration/)

---

## 2. kube-proxy and the alternatives  (lab 11)

Something on each node must translate Service IPs to Pod IPs:

| Implementation | Where the rules live | Look with |
|----------------|----------------------|-----------|
| kube-proxy **iptables** | `KUBE-SERVICES → KUBE-SVC-* → KUBE-SEP-*` NAT chains | `iptables-save -t nat` |
| kube-proxy **ipvs** (deprecated) | IPVS virtual servers on `kube-ipvs0` | `ipvsadm -Ln` |
| kube-proxy **nftables** | nftables table `kube-proxy` | `nft list ruleset` |
| **Cilium KPR** | eBPF maps | `cilium-dbg service list`, `cilium-dbg bpf lb list` |
| **kube-router** | IPVS + GoBGP + ipset | `ipvsadm -Ln`, `gobgp neighbor` |

```bash
kubectl -n kube-system get ds kube-proxy
kubectl -n kube-system get cm kube-proxy -o yaml | grep -E '^\s+mode:'      # "" = iptables
```

kube-router roles (flags): `--run-service-proxy` (replace kube-proxy), `--run-router` (BGP pod routing),
`--run-firewall` (NetworkPolicy). Annotations tune services, e.g. `kube-router.io/service.scheduler: lc`.

Docs: [Virtual IPs and service proxies](https://kubernetes.io/docs/reference/networking/virtual-ips/) ·
[Cilium KPR](https://docs.cilium.io/en/stable/network/kubernetes/kubeproxy-free/) ·
[kube-router](https://www.kube-router.io/docs/user-guide/)

---

## 3. CoreDNS  (labs 12, 13)

The Corefile is in ConfigMap `coredns` (`kube-system`). The `reload` plugin picks up changes after the
kubelet syncs the ConfigMap, which can take ~2 minutes. `kubectl -n kube-system rollout restart deploy coredns` is faster.

Default Corefile (kubeadm):

```text
.:53 {
    errors
    health { lameduck 5s }
    ready
    kubernetes cluster.local in-addr.arpa ip6.arpa {
       pods insecure
       fallthrough in-addr.arpa ip6.arpa
       ttl 30
    }
    prometheus :9153
    forward . /etc/resolv.conf { max_concurrent 1000 }
    cache 30
    loop
    reload
    loadbalance
}
```

Common edits:

```text
# all external lookups to a specific server (lab 13)
    forward . 1.1.1.1

# ONE zone to its own server: a separate TOP-LEVEL server block (lab 12)
corp.internal:53 {
    errors
    cache 30
    forward . 10.0.0.53
}

# static records                      # alias a name                          # debug (remove afterwards)
    hosts {                              rewrite name a.example.internal b.svc.cluster.local    log
       10.0.0.9 legacy.corp
       fallthrough
    }
```

CoreDNS selects the server block with the **longest matching zone**. A zone block nested inside `.:53 { }`
is wrong. Typos are not applied: the old config keeps running and the error is in the logs.

Test and debug:

```bash
kubectl run t --rm -it --image=busybox:1.36 --restart=Never -- nslookup app.corp.internal
kubectl run t --rm -it --image=nicolaka/netshoot --restart=Never -- dig @10.96.0.10 example.com
kubectl -n kube-system logs -l k8s-app=kube-dns
```

"Internal works, external fails" = the `forward` target. "Everything fails" = CoreDNS pods, kube-dns endpoints or a
policy on port 53.

Docs: [Customizing DNS service](https://kubernetes.io/docs/tasks/administer-cluster/dns-custom-nameservers/) ·
[Debugging DNS](https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/) ·
[CoreDNS forward](https://coredns.io/plugins/forward/) · [CoreDNS hosts](https://coredns.io/plugins/hosts/) ·
[CoreDNS rewrite](https://coredns.io/plugins/rewrite/)

---

## 4. Pod endpoint availability  (lab 14)

A Service only sends traffic to **Ready** endpoints. Readiness comes from the **readinessProbe**.

| Probe | Question | Failure means |
|-------|----------|---------------|
| `readinessProbe` | may it receive traffic? | removed from EndpointSlices, **not** restarted |
| `livenessProbe` | is it alive? | container restarted |
| `startupProbe` | has it finished starting? | holds off readiness and liveness until it passes |

```yaml
readinessProbe: {tcpSocket: {port: 8080}, periodSeconds: 5, failureThreshold: 3}
livenessProbe:  {httpGet: {path: /healthz, port: 8080}, initialDelaySeconds: 10}
startupProbe:   {httpGet: {path: /healthz, port: 8080}, failureThreshold: 30, periodSeconds: 5}
```

Triage "Service has no healthy backends":

| Check | Broken when |
|-------|-------------|
| `kubectl get endpointslices -l kubernetes.io/service-name=<svc>` empty | selector ≠ Pod labels |
| endpoints present but `ready: false` | probe failing (port, path, timing) |
| `targetPort` vs `containerPort` | traffic to a port nobody listens on |
| named `targetPort` | name not defined in the Pod |
| `kubectl exec <pod> -- ss -lntp` shows `127.0.0.1` | app bound to loopback |

`publishNotReadyAddresses: true` keeps not-ready Pods in DNS (StatefulSet peers). It is rarely the right fix.

Docs: [Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/) ·
[Debug Services](https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/) ·
[EndpointSlices](https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/)

---

## 5. Gateway API  (labs 15, 16)

| Resource | Owner | Purpose |
|----------|-------|---------|
| `GatewayClass` | infra provider | names the controller (Envoy Gateway, Cilium, Istio, ...) |
| `Gateway` | cluster operator | listeners: port, protocol, hostname, TLS, allowedRoutes |
| `HTTPRoute` | app team | match (path, header, method, query), filters, backends |
| `ReferenceGrant` | target namespace owner | allows cross-namespace refs (backends, Secrets) |

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata: {name: web-gw, namespace: web}
spec:
  gatewayClassName: eg
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    hostname: "shop.example.com"
    allowedRoutes: {namespaces: {from: Same}}
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: {name: shop, namespace: web}
spec:
  parentRefs: [{name: web-gw, sectionName: http}]
  hostnames: ["shop.example.com"]
  rules:
  - matches: [{path: {type: PathPrefix, value: /api}}]        # most specific wins
    backendRefs: [{name: api-v1, port: 8080, weight: 90}, {name: api-v2, port: 8080, weight: 10}]
  - matches: [{headers: [{name: x-canary, value: "true"}]}]
    backendRefs: [{name: api-v2, port: 8080}]
  - matches: [{path: {type: PathPrefix, value: /}}]
    filters: [{type: RequestHeaderModifier, requestHeaderModifier: {add: [{name: x-served-by, value: gateway}]}}]
    backendRefs: [{name: frontend, port: 80}]
```

`backendRefs.port` is the **Service port**. Envoy Gateway install:
`helm install eg oci://docker.io/envoyproxy/gateway-helm --version v1.10.0 -n envoy-gateway-system --create-namespace`
(it brings the Gateway API CRDs). Cilium also implements Gateway API (`gatewayAPI.enabled=true`, KPR required,
install the CRDs **first**, class `cilium`).

Test: `curl --resolve shop.example.com:80:$GW_IP http://shop.example.com/api`, with
`GW_IP=$(kubectl get gateway web-gw -o jsonpath='{.status.addresses[0].value}')`. No LB IP (Killercoda)? Port-forward the
Envoy Service in `envoy-gateway-system`.

### Reading the status  (lab 16)

Gateway: `status.conditions`, `status.listeners[]`. Route: `status.parents[].conditions`.

| Condition / reason | Meaning |
|--------------------|---------|
| GatewayClass `Accepted=Unknown`/`Pending` | no controller claims `controllerName` |
| Gateway `Programmed=False`, `AddressNotAssigned` | no LB IP |
| Route `Accepted=False`, `NoMatchingParent` | `parentRefs` name/`sectionName`/`port` matches no listener |
| Route `Accepted=False`, `NoMatchingListenerHostname` | route hostnames do not overlap the listener hostname |
| Route `Accepted=False`, `NotAllowedByListeners` | `allowedRoutes` excludes the route's namespace |
| Route `ResolvedRefs=False`, `BackendNotFound` / `RefNotPermitted` | wrong Service name/port, or cross-namespace without ReferenceGrant |
| Route has no parent status | `parentRefs` points to a Gateway that does not exist |

When the status is fine and traffic still fails, read the controller log
(`kubectl -n envoy-gateway-system logs deploy/envoy-gateway`) and the Envoy access log (Domain 5).

Docs: [Gateway API](https://gateway-api.sigs.k8s.io/) ·
[Gateway](https://gateway-api.sigs.k8s.io/reference/api-types/gateway/) ·
[HTTPRoute](https://gateway-api.sigs.k8s.io/reference/api-types/httproute/) ·
[HTTP routing guide](https://gateway-api.sigs.k8s.io/guides/http-routing/) ·
[Envoy Gateway](https://gateway.envoyproxy.io/docs/)

---

## 6. Tracing a failing Service

```text
client -> DNS -> ClusterIP/NodePort/LB IP -> translation -> EndpointSlice -> Pod:targetPort
```

```bash
kubectl exec client -- nslookup web.default.svc.cluster.local     # 1 name resolves?
kubectl get svc web -o wide                                       # 2 ports right?
kubectl get endpointslices -l kubernetes.io/service-name=web      # 3 endpoints ready?
kubectl exec client -- curl -m3 <podIP>:<targetPort>              # 4 Pod answers directly?
cilium-dbg service list | grep <clusterIP>   (or iptables-save -t nat | grep <clusterIP>)   # 5 translated?
hubble observe -n default --to-label app=web --verdict DROPPED    # 6 dropped?
```

Step 4 is the split: Pod answers directly but the Service does not = steps 2, 3 or 5. Step 4 fails too = the Pod,
its probes, or a NetworkPolicy.

---

## Checklist

- [ ] Create ClusterIP, NodePort, headless and ExternalName Services from memory (or `kubectl expose`)
- [ ] Explain `externalTrafficPolicy: Local` and what you give up
- [ ] Map an external IP to a cluster name with a selectorless Service + EndpointSlice
- [ ] Tell iptables / ipvs / nftables / Cilium KPR / kube-router apart and show the rules for one Service
- [ ] Forward one zone to a given DNS server, and separately all external lookups
- [ ] Debug a Service with no healthy backends (labels, ports, probes) and add a readiness probe
- [ ] Build a GatewayClass/Gateway/HTTPRoute with path, header and weighted rules
- [ ] Diagnose a broken route from `status.parents` alone
