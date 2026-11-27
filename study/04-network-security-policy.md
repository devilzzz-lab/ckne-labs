# Domain 4: Network Security and Policy (25%)

Official competencies:
1. Securing traffic with network policies
2. Implementing node and pod level encryption
3. Managing TLS certificates for Gateway API
4. Implementing pod-level authentication and authorization

Labs: **22** default deny · **23** Cilium L7 · **24** Cilium FQDN · **25** WireGuard · **26** Gateway TLS Secret ·
**27** cert-manager · **28** TLS troubleshooting · **29** Istio STRICT mTLS · **30** Istio waypoint L7 authz

Two different enforcement layers appear in this domain. The **CNI** enforces NetworkPolicy and
CiliumNetworkPolicy (L3/L4/L7 on the datapath). The **service mesh** enforces PeerAuthentication and
AuthorizationPolicy using workload identity. Decide which layer a task is about before you write anything.

---

## 1. NetworkPolicy vs CiliumNetworkPolicy  (labs 22, 23, 24)

| | Kubernetes `NetworkPolicy` | `CiliumNetworkPolicy` / `CiliumClusterwideNetworkPolicy` |
|--|----------------------------|-----------------------------------------------------------|
| Scope | namespaced | namespaced (CNP) or cluster-wide (CCNP) |
| Layers | L3, L4 | L3, L4, **L7** (HTTP, DNS) |
| Peers | Pods, namespaces, ipBlock | endpoints, **entities** (`world`, `host`, `kube-apiserver`, `cluster`...), CIDR, **FQDN**, services |
| Deny | no (allow only) | `ingressDeny` / `egressDeny`, **deny always wins** |
| Node policy | no | CCNP with `nodeSelector` |

**Shared model:** a Pod is open in a direction until a policy **selects** it for that direction. After that only what some
policy allows gets through. Policies **add up** (union). A connection needs egress allowed on the client **and** ingress
allowed on the server (when both ends are selected). Write rules against Pods, never Service IPs (translation happens first).

### Default deny, DNS, allow-list (lab 22)

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: default-deny, namespace: shop}
spec: {podSelector: {}, policyTypes: [Ingress, Egress]}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: allow-dns, namespace: shop}
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
  - to:
    - namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: kube-system}}
      podSelector: {matchLabels: {k8s-app: kube-dns}}      # same item = AND
    ports: [{protocol: UDP, port: 53}, {protocol: TCP, port: 53}]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: api-from-frontend, namespace: shop}
spec:
  podSelector: {matchLabels: {app: api}}
  policyTypes: [Ingress]
  ingress:
  - from:
    - podSelector: {matchLabels: {app: frontend}}
    ports: [{protocol: TCP, port: 8080}]
```

> **Trap:** `from: [ {namespaceSelector}, {podSelector} ]` (two items) = **OR**.
> `from: [ {namespaceSelector, podSelector} ]` (one item) = **AND**.
> **Trap:** default-deny egress also blocks DNS. Always add the DNS rule.

### Cilium L7 HTTP (lab 23)

`rules.http` on a `toPorts` entry routes that port through Cilium's Envoy. Requests matching no rule get **HTTP 403**
(the connection was allowed, L7 refused). `method` and `path` are anchored **regular expressions**; a listed header
without a value only requires presence.

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata: {name: api-l7, namespace: shop}
spec:
  endpointSelector: {matchLabels: {app: api}}
  ingress:
  - fromEndpoints: [{matchLabels: {app: frontend}}]
    toPorts:
    - ports: [{port: "8080", protocol: TCP}]
      rules:
        http:
        - {method: GET, path: "/products(/.*)?"}
        - {method: POST, path: "/cart", headers: ["X-Session"]}
```

| Result | Meaning |
|--------|---------|
| timeout | dropped at L3/L4: no rule for this identity/port |
| `403 Access denied` | L4 allowed, no L7 rule matched |
| works for one path only | regex too narrow or anchored unexpectedly |

### FQDN egress (lab 24)

```yaml
egress:
- toEndpoints: [{matchLabels: {k8s:io.kubernetes.pod.namespace: kube-system, k8s:k8s-app: kube-dns}}]
  toPorts:
  - ports: [{port: "53", protocol: ANY}]
    rules: {dns: [{matchPattern: "*"}]}          # REQUIRED: lets the DNS proxy learn the IPs
- toFQDNs: [{matchName: example.com}]            # or matchPattern: "*.example.com"
  toPorts: [{ports: [{port: "443", protocol: TCP}]}]
```

Without the DNS rule `toFQDNs` allows nothing. Deny rules cannot use `toFQDNs` or L7 rules. A lone deny rule puts the
Pod into default-deny, so pair it with a broad allow (`toEntities: [all]`).

```bash
kubectl get netpol,cnp -A
kubectl -n kube-system exec ds/cilium -- cilium-dbg policy get
hubble observe --type policy-verdict --verdict DROPPED
```

Docs: [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/) ·
[Cilium policy language](https://docs.cilium.io/en/stable/security/policy/language/) ·
[Cilium L7](https://docs.cilium.io/en/stable/security/policy/language/#layer-7-examples) ·
[Cilium DNS-based](https://docs.cilium.io/en/stable/security/policy/language/#dns-based) ·
[Calico NetworkPolicy](https://docs.tigera.io/calico/latest/network-policy/get-started/calico-policy/calico-network-policy)

---

## 2. Node and Pod encryption  (lab 25)

Cilium encrypts Pod-to-Pod traffic **between nodes** with WireGuard (or IPsec), without changing applications.
Each node publishes a public key on its `CiliumNode`. Traffic goes through `cilium_wg0`, UDP **51871**. Pods on the
same node are not encrypted (it never leaves the host).

```bash
cilium install --set encryption.enabled=true --set encryption.type=wireguard
cilium upgrade --reuse-values --set encryption.enabled=true --set encryption.type=wireguard \
                              --set encryption.nodeEncryption=true          # also node-to-node
kubectl -n kube-system rollout restart ds/cilium
```

| Value | Effect |
|-------|--------|
| `encryption.enabled=true` + `type=wireguard` | encrypt cross-node Pod traffic |
| `encryption.nodeEncryption=true` | also encrypt node-to-node (host) traffic |
| `encryption.type=ipsec` | IPsec with a pre-shared-key Secret instead |

Verify:

```bash
kubectl -n kube-system exec ds/cilium -- cilium-dbg status | grep Encryption
#   Encryption: Wireguard [NodeEncryption: Enabled, cilium_wg0 (Pubkey: ..., Port: 51871, Peers: N)]
kubectl -n kube-system exec ds/cilium -- cilium-dbg encrypt status
tcpdump -i any -nn udp port 51871          # cross-node Pod traffic only shows up like this on the NIC
tcpdump -i cilium_wg0 -nn                  # plaintext only on the WireGuard device
```

`Peers` = number of other nodes. `0` or plaintext on the NIC = not in effect. Large requests hanging after enabling =
MTU. Needs kernel with WireGuard (5.6+).

Docs: [WireGuard](https://docs.cilium.io/en/stable/security/network/encryption-wireguard/) ·
[IPsec](https://docs.cilium.io/en/stable/security/network/encryption-ipsec/) ·
[Encryption overview](https://docs.cilium.io/en/stable/security/network/encryption/)

---

## 3. TLS for the Gateway API  (labs 26, 27, 28)

### Secret by hand (lab 26)

```bash
kubectl -n web create secret tls shop-tls --cert=shop.crt --key=shop.key         # type kubernetes.io/tls
# practice cert:
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt \
  -subj "/CN=shop.example.com" -addext "subjectAltName=DNS:shop.example.com"
```

```yaml
listeners:
- name: https
  protocol: HTTPS
  port: 443
  hostname: shop.example.com
  tls:
    mode: Terminate                  # Passthrough + TLSRoute forwards encrypted bytes untouched
    certificateRefs: [{kind: Secret, name: shop-tls}]      # +namespace: needs a ReferenceGrant
---
# HTTPRoute attaches to ONE listener with sectionName
parentRefs: [{name: web-gw, sectionName: https}]
```

HTTP→HTTPS redirect: a route on the `http` listener with `filters: [{type: RequestRedirect, requestRedirect: {scheme: https, statusCode: 301}}]`.
Cross-namespace Secret: `ReferenceGrant` **in the Secret's namespace** (`from` Gateway namespace, `to` kind Secret).
`BackendTLSPolicy` makes the gateway use TLS **to** the backend.

### cert-manager (lab 27)

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata: {name: selfsigned}
spec: {selfSigned: {}}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata: {name: shop-cert, namespace: web}
spec:
  secretName: shop-tls
  dnsNames: [shop.example.com]
  issuerRef: {name: selfsigned, kind: ClusterIssuer}
```

Chain: **Issuer → Certificate → CertificateRequest → (Order) → Secret**. Alternative: annotate the Gateway with
`cert-manager.io/cluster-issuer: selfsigned`. cert-manager then creates the Certificate for each `certificateRefs`
Secret on a listener with a `hostname` and `tls.mode: Terminate`. It needs `config.enableGatewayAPI=true` and the Gateway
API CRDs present at startup (restart cert-manager otherwise).

```bash
kubectl -n web get certificate,certificaterequest
kubectl -n web describe certificate shop-cert          # why not Ready
kubectl -n cert-manager logs deploy/cert-manager
```

### Verify and troubleshoot (lab 28)

```bash
curl -vk --resolve shop.example.com:443:$GW_IP https://shop.example.com/
openssl s_client -connect $GW_IP:443 -servername shop.example.com </dev/null 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates -ext subjectAltName
kubectl describe gateway web-gw
```

| Condition / symptom | Cause |
|---------------------|-------|
| listener `ResolvedRefs=False`, `InvalidCertificateRef` | Secret missing, wrong name, or not `kubernetes.io/tls` |
| `RefNotPermitted` | Secret in another namespace and no ReferenceGrant |
| wrong certificate served | SNI hostname ≠ listener hostname. Always pass `-servername` / `--resolve` |
| Certificate never `Ready` | `issuerRef` name/kind wrong, issuer not Ready, solver failing (ACME) |
| expired / name mismatch | read `-dates` and `subjectAltName` |
| route `NoMatchingParent` | `sectionName` typo |

Docs: [Gateway API TLS](https://gateway-api.sigs.k8s.io/guides/tls/) ·
[ReferenceGrant](https://gateway-api.sigs.k8s.io/reference/api-types/referencegrant/) ·
[cert-manager](https://cert-manager.io/docs/) · [Gateway usage](https://cert-manager.io/docs/usage/gateway/) ·
[cert-manager troubleshooting](https://cert-manager.io/docs/troubleshooting/)

---

## 4. Pod-level authentication and authorization: Istio ambient  (labs 29, 30)

| Component | Layer | Role |
|-----------|-------|------|
| **ztunnel** (DaemonSet) | L4 | transparent mTLS (HBONE), SPIFFE identity per ServiceAccount, L4 AuthorizationPolicy |
| **waypoint** (Envoy, per namespace/service) | L7 | HTTP routing, **L7 AuthorizationPolicy**, retries, telemetry |
| istio-cni | node | redirects Pod traffic to ztunnel. No sidecars |

```text
client pod -> ztunnel(node A) ==mTLS/HBONE==> [waypoint, only if L7] ==> ztunnel(node B) -> server pod
```

```bash
istioctl install --set profile=ambient --skip-confirmation
kubectl label ns shop istio.io/dataplane-mode=ambient              # enrol, no restarts
kubectl label pod <pod> istio.io/dataplane-mode=none               # take one Pod out
istioctl waypoint apply -n shop --enroll-namespace --wait          # adds the waypoint + istio.io/use-waypoint label
istioctl ztunnel-config workloads
istioctl analyze -n shop
```

> Ambient on **Cilium**: use `cni.exclusive=false`; with KPR set `socketLB.hostNamespaceOnly=true`;
> `bpf.masquerade=true` is **not supported**; with default-deny allow ingress from `169.254.7.127/32` (SNATed kubelet probes).
> That is why labs 29-30 need the Calico session.

### Authentication vs authorization (lab 29)

| Resource | Question |
|----------|----------|
| `PeerAuthentication` | **who may connect, and must it be mTLS?** |
| `AuthorizationPolicy` | **what may an authenticated caller do?** |

| Client | Server | PERMISSIVE (default) | STRICT |
|--------|--------|----------------------|--------|
| mesh | mesh | mTLS | mTLS |
| non-mesh | mesh | plaintext accepted | **rejected** |
| mesh | non-mesh | plaintext | plaintext |

```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata: {name: default, namespace: bank}      # name "default" + no selector = whole namespace
spec: {mtls: {mode: STRICT}}
```

### L4 vs L7 authorization (lab 30)

```yaml
# L4: selector, enforced by ztunnel. Only identity, namespace, IP, port are visible.
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata: {name: api-l4, namespace: shop}
spec:
  selector: {matchLabels: {app: api}}
  action: ALLOW
  rules:
  - from: [{source: {principals: ["cluster.local/ns/shop/sa/frontend"]}}]
    to: [{operation: {ports: ["8080"]}}]
---
# L7: targetRefs (Service or waypoint Gateway), enforced by the waypoint. Methods, paths, headers.
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata: {name: api-l7, namespace: shop}
spec:
  targetRefs: [{kind: Service, group: "", name: api}]
  action: ALLOW
  rules:
  - from: [{source: {principals: ["cluster.local/ns/shop/sa/frontend"]}}]
    to: [{operation: {methods: ["GET"], paths: ["/products", "/products/*"]}}]
```

**Evaluation order:** CUSTOM → DENY → ALLOW. Once any ALLOW policy targets a workload, every request matching none of its
rules is denied. Principal format: `cluster.local/ns/<ns>/sa/<sa>`. With a waypoint in the path, a ztunnel-level policy
on the destination sees the **waypoint's** identity.

| Symptom | Layer / cause |
|---------|---------------|
| HTTP 403 `RBAC: access denied` | waypoint (L7) rejected it |
| `Connection reset` / `recv failure` | ztunnel (L4) policy, or STRICT mTLS rejecting a non-mesh client |
| L7 policy has no effect | no waypoint, or the Service does not use it (`istio.io/use-waypoint`) |
| L7 **ALLOW** via `selector` blocks everything | ztunnel cannot evaluate the rule, so nothing matches. Use `targetRefs` |
| L7-only **DENY** via `selector` does nothing | rule skipped. Use `targetRefs` |
| principal never matches | wrong namespace or ServiceAccount in the string |
| non-mesh client still gets through | PeerAuthentication not STRICT, or namespace not labelled |

```bash
kubectl -n shop get pod <client> -o jsonpath='{.spec.serviceAccountName}'
kubectl -n istio-system logs -l app=ztunnel | grep -iE "policy rejection|denied"
kubectl -n shop logs deploy/waypoint | grep -i rbac
```

Docs: [Istio ambient](https://istio.io/latest/docs/ambient/) ·
[Add workloads](https://istio.io/latest/docs/ambient/usage/add-workloads/) ·
[Waypoint](https://istio.io/latest/docs/ambient/usage/waypoint/) ·
[L7 features](https://istio.io/latest/docs/ambient/usage/l7-features/) ·
[AuthorizationPolicy](https://istio.io/latest/docs/reference/config/security/authorization-policy/) ·
[PeerAuthentication](https://istio.io/latest/docs/reference/config/security/peer_authentication/) ·
[Security concepts](https://istio.io/latest/docs/concepts/security/) ·
[Ambient with Cilium](https://docs.cilium.io/en/stable/network/servicemesh/istio/)

---

## Checklist

- [ ] When is a NetworkPolicy enough, and when do you need a CiliumNetworkPolicy?
- [ ] Default deny, then open DNS and one app port. Explain why both sides need a rule
- [ ] Restrict a Pod's egress to one FQDN (and say why the DNS rule is mandatory)
- [ ] Allow specific HTTP methods/paths with Cilium L7, and explain 403 vs timeout
- [ ] Enable WireGuard + node encryption and prove it with status and `tcpdump`
- [ ] Serve HTTPS from a Gateway with a given certificate, including a Secret in another namespace
- [ ] Have cert-manager issue a Gateway certificate and read why one is not Ready
- [ ] Enrol a namespace in ambient, make plaintext non-mesh clients fail with STRICT
- [ ] Write both an L4 and an L7 AuthorizationPolicy and pick the right one
- [ ] Debug a denied request from the ztunnel and waypoint logs
