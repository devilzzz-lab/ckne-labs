# 🎯 CKNE Practice Labs

**34 exam-style hands-on scenarios** plus **study notes with sources** for the
**Certified Kubernetes Network Engineer (CKNE)** exam, built for the **Killercoda Kubernetes
playground** (2-node kubeadm: `controlplane` + `node01`).

Same format as `cka-labs`: each scenario has `TASK.md`, `setup.sh`, `check.sh`, `cleanup.sh`
and `solution.md`, driven by an interactive runner.

> CKNE has no official simulator yet. The exam questions are not public, so these tasks are
> **custom-built** from the official domains and competencies and from candidate reports taken during the September beta.
> See [`study/00-exam-guide.md`](study/00-exam-guide.md) and [`study/07-resources.md`](study/07-resources.md).

---

## Quick start (Killercoda)

```bash
# 1. Open a Killercoda Kubernetes playground (2 nodes), on the controlplane:
git clone <this-repo> && cd ckne-labs

# 2. One-time check (cluster, ssh node01, which CNI you have):
./cluster/create-cluster.sh

# 3. Study:
./ckne.sh
```

### Two sessions (important)

Istio ambient does not work with Cilium's `bpf.masquerade=true`, and the Cilium egress gateway needs it.
So the labs are split. Switching sessions = **restart the Killercoda playground**.

| Session | CNI | How to get it | Labs |
|---------|-----|---------------|------|
| **A** | not Cilium-with-BPF-masquerade (a Calico playground, or Cilium with it off) | nothing to do | every lab tagged `[A or B]` or `[A: Calico, Istio]` |
| **B** | Cilium with KPR + BPF masquerade | do **lab 01** (it removes any existing CNI first, you install Cilium) or run `./cluster/install-cilium.sh` | every lab tagged `[B: Cilium]` and all `[A or B]` |

Each setup script checks this and stops with a clear message if the session is wrong.
Suggested order: do **A** first, restart, then **B**.

---

## How it works

```
╔═══════════════════════════════════════════════════════════════╗
║             CKNE Practice Labs - Study Mode                   ║
╚═══════════════════════════════════════════════════════════════╝

  ▶ Scenario 15/34: Gateway API path routing
    Domain 2   [A or B]

    [r] Run/Setup   [t] Task   [s] Solution   [c] Check
    [g] Study guide for this domain
    [x] Reset   [f] Full reset   [d] Done & next   [n]/[p]   [l] List   [q] Quit
```

1. **`[r]`** sets up the broken/empty environment and prints the task.
2. Solve it in **another terminal** (use the docs links in the task, like the exam).
3. **`[c]`** runs the automated check. It checks real behaviour (curl, status, Pod IPs), not just YAML.
4. **`[s]`** shows the solution **and the "why"**. Read it even when you passed.
5. **`[g]`** opens the study note for the domain. **`[d]`** marks done.

Answer-type tasks (Domain 1, 5) write files to `/opt/answers/*.txt`, like the browser answer box in the exam.

Non-interactive: `./run.sh 05` · `./check.sh 05` · `./reset.sh 05`.

---

## All 34 scenarios

| # | Domain | Lab | What you do | Session |
|---|:------:|-----|-------------|:-------:|
| 01 | 1 | Install Cilium, kube-proxy replacement | `cilium install` with KPR + BPF masquerade on a CNI-less cluster | B |
| 02 | 1 | IPAM / Pod CIDR | read IPAM mode, cluster CIDR, node CIDR from the cluster | B |
| 03 | 1 | tcpdump | capture exactly 25 packets to port 8080 into a pcap on node01 | A/B |
| 04 | 1 | iptables | find and delete one rogue DROP rule, keep the others | A/B |
| 05 | 1 | tc netem | find and remove 300 ms injected latency | A/B |
| 06 | 1 | Pod DNS | Pod with `dnsPolicy: None` cannot resolve cluster names | A/B |
| 07 | 1 | Multus | NAD (bridge + host-local) and a Pod with `eth0` + `net1` | A/B |
| 08 | 2 | Service types | ClusterIP, NodePort 30088, headless, ExternalName | A/B |
| 09 | 2 | Selectorless Service | Service + hand-written EndpointSlice to an external server | A/B |
| 10 | 2 | MetalLB | IPAddressPool + L2Advertisement, LoadBalancer gets an IP | A/B |
| 11 | 2 | Which proxy? | identify iptables/ipvs/nftables/Cilium and read the backends from the dataplane | A/B |
| 12 | 2 | CoreDNS zone forward | forward `corp.internal` to a corporate DNS Service | A/B |
| 13 | 2 | CoreDNS external fix | broken `forward` target, fix to `1.1.1.1` | A/B |
| 14 | 2 | No endpoints | wrong selector + targetPort, add a readiness probe | A/B |
| 15 | 2 | Gateway path routing | Gateway + HTTPRoute (`/api` and `/`) with Envoy Gateway | A/B |
| 16 | 2 | Gateway troubleshooting | three faults in an HTTPRoute, found from `status` | A/B |
| 17 | 3 | Inference Gateway | InferencePool + HTTPRoute for `POST /v1/completions` | A/B |
| 18 | 3 | Cilium BGP | enable control plane, ClusterConfig, PeerConfig, Advertisement (FRR router Pod) | B |
| 19 | 3 | Cilium egress gateway | enable feature, label node, `CiliumEgressGatewayPolicy` | B |
| 20 | 3 | Cluster Mesh repair | fix duplicate id/name/CIDR, `useAPIServer`, global-service annotation, CA copy | A/B |
| 21 | 3 | Istio registry-only egress | `Sidecar` REGISTRY_ONLY + `ServiceEntry` | A |
| 22 | 4 | NetworkPolicy lockdown | default deny, DNS, frontend → api only | A/B |
| 23 | 4 | Cilium L7 policy | only `GET /products(/.*)?`, everything else 403 | B |
| 24 | 4 | Cilium FQDN egress | only `example.com:443` + DNS | B |
| 25 | 4 | WireGuard | pod + node encryption, prove with status / peers | B |
| 26 | 4 | Gateway TLS Secret | `kubectl create secret tls`, HTTPS listener, route `sectionName` | A/B |
| 27 | 4 | cert-manager + Gateway | ClusterIssuer, Certificate, HTTPS listener | A/B |
| 28 | 4 | Gateway TLS broken | issuerRef typo, wrong certificateRef, wrong sectionName | A/B |
| 29 | 4 | Istio ambient STRICT mTLS | enrol namespace, PeerAuthentication STRICT, non-mesh client rejected | A |
| 30 | 4 | Istio waypoint + L7 authz | waypoint, `targetRefs`, only `teller` may `POST /transfer` | A |
| 31 | 5 | Hubble drops | find the dropped client, the reason, fix it narrowly | B |
| 32 | 5 | Prometheus | find the failing Pod, write the PromQL | A/B |
| 33 | 5 | Jaeger | find the slow hop and the erroring service | A/B |
| 34 | 5 | Envoy access logs | find the user agent and IP hammering `/api/login` | A/B |

Weights in the exam: D1 15% · D2 25% · D3 20% · D4 25% · D5 15%. The lab count follows that.

---

## Study notes (`study/`)

| File | Content |
|------|---------|
| [`00-exam-guide.md`](study/00-exam-guide.md) | format, time plan, per-task routine, traps, how to use the labs |
| [`01-core-infrastructure-cni.md`](study/01-core-infrastructure-cni.md) | CNI, Cilium install, KPR, IPAM, tcpdump/iptables/tc, Multus |
| [`02-service-networking-dns.md`](study/02-service-networking-dns.md) | Services, EndpointSlices, MetalLB, kube-proxy vs Cilium, CoreDNS, probes, Gateway API |
| [`03-advanced-traffic-management.md`](study/03-advanced-traffic-management.md) | Inference extension, BGP, egress gateways, Cluster Mesh |
| [`04-network-security-policy.md`](study/04-network-security-policy.md) | NetworkPolicy, Cilium L7/FQDN, WireGuard, Gateway TLS, cert-manager, Istio ambient |
| [`05-observability.md`](study/05-observability.md) | Hubble, Prometheus, Jaeger, Envoy logs |
| [`06-cheatsheet.md`](study/06-cheatsheet.md) | commands, Helm values, PromQL, status decoders |
| [`07-resources.md`](study/07-resources.md) | **every link and source**, grouped by tool |

---

## What these labs install

Setup scripts install what a lab needs and leave it for the next lab (pinned versions in `lib/common.sh`):
Envoy Gateway (also supplies the Gateway API CRDs), MetalLB, cert-manager, Istio (ambient profile),
Multus, the Inference Extension CRDs, Hubble, plus small helper Pods (Prometheus, Jaeger, an FRR router).
Needs internet access. Killercoda has it.

Each lab's `cleanup.sh` removes what the lab created. Labs that change the CNI (01, 25) cannot be undone:
**restart the playground**.

## Honest limits

- **The labs have not been run on a real Killercoda playground yet.** Scripts were syntax-checked and
  the versions and URLs were verified, but the first real run may need small fixes. Tell me which lab
  misbehaves and I will fix it.
- **17 (inference)** checks your configuration. There is no GPU and no real endpoint picker.
- **18 (BGP)**: the router is an FRR Pod. The checks score your resources. The session state is printed for information only.
- **20 (Cluster Mesh)** is a configuration repair. Killercoda gives one cluster, so a real two-cluster mesh is not possible.
- **21 (Istio egress)** teaches `REGISTRY_ONLY` + `ServiceEntry` in sidecar mode. The egress-gateway part is a stretch goal in the solution.
- **10 (MetalLB)** checks IP assignment. The Killercoda nodes sit on different subnets, so L2 reachability is not testable.
- Observability labs (32, 33) use small synthetic apps so the data is deterministic. The UIs are the real Prometheus and Jaeger.

---

## File structure

```
ckne-labs/
├── ckne.sh                      # interactive runner
├── run.sh / check.sh / reset.sh # non-interactive helpers
├── lib/common.sh               # shared helpers, pinned versions, check framework
├── cluster/                    # create-cluster.sh, install-cilium.sh, destroy-cluster.sh
├── study/                      # notes, cheatsheet, resources
└── scenario-NN-name/           # TASK.md, setup.sh, check.sh, cleanup.sh, solution.md
```

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `kubectl` cannot connect | `crictl ps \| grep kube-apiserver`; `systemctl restart kubelet; sleep 30; kubectl get nodes` |
| "This scenario needs Cilium" | do lab 01 or `./cluster/install-cilium.sh` |
| "Istio ambient does not work with bpf.masquerade" | restart the playground (session A) |
| Setup fails on `AlreadyExists` | press `[x]` (reset) then `[r]` again |
| A Pod is `ImagePullBackOff` | check internet access from the node, `kubectl describe pod` |
| CoreDNS lab left DNS broken | `./reset.sh 12` or `./reset.sh 13` restores the original Corefile |

Good luck with CKNE! ⭐
