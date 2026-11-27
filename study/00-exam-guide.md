# CKNE Exam Guide: format, strategy, and how to use these labs

CKNE = **Certified Kubernetes Network Engineer** (Linux Foundation / CNCF). The exam was released on
10 November 2026. Several sources below were written during the **September beta**, so details such as
scoring or task count may have changed. Re-check the official pages before you book.

## 1. Facts

| Item | Value | Source |
|------|-------|--------|
| Style | Performance-based (hands-on), proctored, online | [LF CKNE page](https://training.linuxfoundation.org/certification/certified-kubernetes-network-engineer-ckne/) |
| Tasks | about 15-20 | [Bibin Wilson's guide](https://devopscube.com/ckne-exam-learning-path/) |
| Duration | 2 hours | same |
| Kubernetes version | v1.37 (per the exam instructions) | [Important Instructions: CKNE](https://docs.linuxfoundation.org/tc-docs/certification/important-instructions-ckne) |
| Retake | one retake included, take the exam within 12 months of purchase | LF page |
| Validity | 2 years | LF page |
| Prerequisite | none, but CKA-level Kubernetes skills are assumed | LF page |

## 2. Domains and weights (official)

| # | Domain | Weight | Study note | Labs |
|---|--------|:------:|------------|------|
| 1 | Core Infrastructure and CNI | 15% | [01](01-core-infrastructure-cni.md) | 01-07 |
| 2 | Service Networking and DNS | 25% | [02](02-service-networking-dns.md) | 08-16 |
| 3 | Advanced Traffic Management | 20% | [03](03-advanced-traffic-management.md) | 17-21 |
| 4 | Network Security and Policy | 25% | [04](04-network-security-policy.md) | 22-30 |
| 5 | Observability | 15% | [05](05-observability.md) | 31-34 |

Official competency list: [CKNE domains and competencies](https://training.linuxfoundation.org/certification/certified-kubernetes-network-engineer-ckne/).

## 3. Tools you may meet

Cilium, Istio, Envoy, Gateway API, Hubble, Prometheus, Helm, Jaeger, cert-manager.

**Allowed documentation** (see [Resources Allowed](https://docs.linuxfoundation.org/tc-docs/certification/certification-resources-allowed)):
the Kubernetes docs and blog, the [Cilium docs](https://docs.cilium.io/), the
[Istio docs](https://istio.io/latest/docs/), plus the links in each task's *Quick Reference* box.
Everything is in [07-resources.md](07-resources.md).

## 4. What beta candidates reported (September 2026)

From [Jan-Otto Kröpke's beta report](https://jkroepke.de/) (taken 17 September 2026) and the
[devopscube study guide](https://devopscube.com/ckne-exam-learning-path/):

- **Breadth beats depth.** You move quickly across CNI, Services, Gateway API, Cilium, Istio, security
  and observability. Two hours is tight.
- **Do not memorise CRD YAML.** The environment gave context and documentation links. Learn **what a
  resource is for**, find the example, adapt it, validate, move on.
- **Know the basics cold:** a broken Service is often a wrong `port` / `targetPort`. Services without
  selectors need a hand-written EndpointSlice (label `kubernetes.io/service-name`, explicit address).
- **Observability is UI driven.** Prometheus, Jaeger and Hubble UIs were pre-installed. Metric names and
  complex PromQL were not required from memory.
- **Gateway access logs matter:** tell normal, rejected and suspicious traffic apart, and pull the
  client/user-agent out.
- **Answers can be typed in the browser UI**, which then writes the file (no more `/opt/...` in some tasks).
  These labs use `/opt/answers/*.txt` to mimic that.
- **Time was the main problem.** Solve, validate, move on. Return later if stuck.
- Low-level tools (`ip`, `tcpdump`) were less important than expected, but the **official domain list still
  names them**. Practise them (labs 03, 04, 05).

## 5. Time plan (120 minutes)

| Pass | Minutes | Do |
|------|:-------:|----|
| 1 | ~60 | Quick wins: CoreDNS, Services, probes, NetworkPolicy, Gateway routes, observability lookups |
| 2 | ~45 | Multi-step builds: BGP, egress gateway, Cluster Mesh, Istio policies, inference routing |
| 3 | ~15 | Re-run every provided verification command |

Rules of thumb:
- More than **8 minutes** with no progress → flag it and move on.
- Read the whole task and write down every **exact value** (names, namespaces, ports, IPs, CIDRs, file
  paths, counts). Scoring is automatic, so a working answer with the wrong name still fails.
- **Run the provided check first** to see the failure, then again after the fix.
- Sketch the traffic path (client → gateway → route → policy → service → pod) when there are more than two hops.
- Check the **hostname in your prompt** before every change (wrong host = zero).

## 6. Per-task routine

```text
1. ssh <designated-host>             (from the task box)
2. Read the task. Note exact values.
3. Run the provided test -> see the failure
4. Open the Quick Reference links. Do not search from memory.
5. Fix / build, using the docs
6. Run the provided test -> see it pass
7. exit (back to base). Never nest ssh sessions.
```

Setup that fits on one line (each task starts a fresh session):

```bash
export do="--dry-run=client -o yaml" now="--force --grace-period=0"
printf 'set tabstop=2 shiftwidth=2 expandtab\n' >> ~/.vimrc
```

`k`, `kubectl` completion, `yq`, `curl`, `wget`, `man` exist on the task hosts. Terminal copy/paste is
`Ctrl+Shift+C` / `Ctrl+Shift+V`. Do not use plain `Ctrl+W` in the remote desktop (it closes the browser tab).

## 7. Common traps

| Trap | Prevention |
|------|-----------|
| Wrong host | Check the prompt before every change |
| Default-deny egress breaks DNS | Always allow UDP+TCP 53 to kube-dns |
| Cilium setting changed but not applied | After `cilium upgrade`, `rollout restart ds/cilium` **and** `deploy/cilium-operator` |
| Hand-written EndpointSlice ignored | Missing `kubernetes.io/service-name` label, or port name mismatch |
| `namespaceSelector` + `podSelector` as two list items (OR) instead of one (AND) | Read the YAML dashes |
| L7 Istio rule written with `selector` | Use `targetRefs` + a waypoint |
| HTTPRoute `backendRefs.port` = container port | It is the **Service** port |
| Testing HTTPS without SNI | `curl --resolve host:443:IP`, `openssl s_client -servername host` |
| Cluster Mesh never connects | duplicate `cluster.id`, overlapping pod CIDRs, no shared CA |
| Waiting for CoreDNS `reload` | `kubectl -n kube-system rollout restart deploy coredns` |

## 8. How to use these labs (Killercoda)

Two playground sessions, because Istio ambient and Cilium's eBPF masquerading do not coexist:

| Session | CNI | Scenarios |
|---------|-----|-----------|
| **A** | default Calico | everything tagged `any` or `calico` (3-17, 20-22, 26-30, 32-34) |
| **B** | Cilium (do lab 01 or `cluster/install-cilium.sh`) | tagged `cilium` (1, 2, 18, 19, 23, 24, 25, 31) and all `any` labs |

Suggested order: work through **Session A** first (it is the default playground), restart the
playground, then do **Session B**. Use `[g]` in `./ckne.sh` to open the study note for the lab you are on.

Study loop for each lab: read the domain note → run the lab → solve without the solution →
`[c]` check → read the solution anyway (it has "why" notes) → redo it from scratch the next day.
