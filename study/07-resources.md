# Sources and links

Everything here was checked on 2026-11-27. Documentation sites marked **(exam)** are on the allowed-resources list
(see the [official list](https://docs.linuxfoundation.org/tc-docs/certification/certification-resources-allowed)).

## Official CKNE

- [CKNE program page: domains, competencies, prerequisites](https://training.linuxfoundation.org/certification/certified-kubernetes-network-engineer-ckne/)
- [Important Instructions: CKNE](https://docs.linuxfoundation.org/tc-docs/certification/important-instructions-ckne) (environment, tools, Kubernetes v1.37)
- [Resources Allowed](https://docs.linuxfoundation.org/tc-docs/certification/certification-resources-allowed)
- [FAQ: CKNE](https://docs.linuxfoundation.org/tc-docs/certification/frequently-asked-questions-ckne)

## Candidate write-ups (the references behind this repo)

- [Jan-Otto Kröpke: Preparing for CKNE, what I learned from the beta exam](https://jkroepke.de/) (taken 2026-09-17)
- [Bibin Wilson: CKNE Certification Exam Learning Path](https://devopscube.com/ckne-exam-learning-path/)
- [techiescamp/ckne-learning-path](https://github.com/techiescamp/ckne-learning-path) (All Rights Reserved licence: read it, do not copy it)
- Other guides: [Stéphane Robert's CKNE pages](https://www.stephane-robert.info/en/docs/conteneurs/orchestrateurs/kubernetes/certifications/ckne/),
  [devops-daily](https://devops-daily.com/posts/ckne-kubernetes-network-engineer-exam-guide)

## Kubernetes (exam)

- [Services](https://kubernetes.io/docs/concepts/services-networking/service/) ·
  [EndpointSlices](https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/) ·
  [Virtual IPs and service proxies](https://kubernetes.io/docs/reference/networking/virtual-ips/) ·
  [Topology aware routing](https://kubernetes.io/docs/concepts/services-networking/topology-aware-routing/)
- [DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/) ·
  [Customizing DNS service](https://kubernetes.io/docs/tasks/administer-cluster/dns-custom-nameservers/) ·
  [Debugging DNS](https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/)
- [Debug Services](https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/) ·
  [Debug Pods](https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/)
- [Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/) ·
  [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) ·
  [Gateway API (k8s.io overview)](https://kubernetes.io/docs/concepts/services-networking/gateway/)
- [Network plugins / CNI](https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/) ·
  [CNI spec](https://github.com/containernetworking/cni/blob/main/SPEC.md)

## Cilium (exam)

- [Docs home](https://docs.cilium.io/) · [Helm reference](https://docs.cilium.io/en/stable/helm-reference/)
- [Quick install](https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/) ·
  [Kubernetes without kube-proxy](https://docs.cilium.io/en/stable/network/kubernetes/kubeproxy-free/) ·
  [Masquerading](https://docs.cilium.io/en/stable/network/concepts/masquerading/) ·
  [IPAM](https://docs.cilium.io/en/stable/network/concepts/ipam/)
- [BGP Control Plane](https://docs.cilium.io/en/stable/network/bgp-control-plane/bgp-control-plane-v2/) ·
  [Egress Gateway](https://docs.cilium.io/en/stable/network/egress-gateway/egress-gateway/) ·
  [Cluster Mesh](https://docs.cilium.io/en/stable/network/clustermesh/clustermesh/) ·
  [Global services](https://docs.cilium.io/en/stable/network/clustermesh/services/)
- [Policy language](https://docs.cilium.io/en/stable/security/policy/language/) ·
  [WireGuard](https://docs.cilium.io/en/stable/security/network/encryption-wireguard/) ·
  [IPsec](https://docs.cilium.io/en/stable/security/network/encryption-ipsec/)
- [Hubble](https://docs.cilium.io/en/stable/observability/hubble/) ·
  [Metrics](https://docs.cilium.io/en/stable/observability/metrics/) ·
  [Istio ambient on Cilium](https://docs.cilium.io/en/stable/network/servicemesh/istio/)

## Istio (exam)

- [Docs home](https://istio.io/latest/docs/) · [Ambient mode](https://istio.io/latest/docs/ambient/)
- [Add workloads](https://istio.io/latest/docs/ambient/usage/add-workloads/) ·
  [Waypoint](https://istio.io/latest/docs/ambient/usage/waypoint/) ·
  [L7 features](https://istio.io/latest/docs/ambient/usage/l7-features/)
- [AuthorizationPolicy](https://istio.io/latest/docs/reference/config/security/authorization-policy/) ·
  [PeerAuthentication](https://istio.io/latest/docs/reference/config/security/peer_authentication/) ·
  [Security concepts](https://istio.io/latest/docs/concepts/security/)
- [Egress control](https://istio.io/latest/docs/tasks/traffic-management/egress/egress-control/) ·
  [Egress gateways](https://istio.io/latest/docs/tasks/traffic-management/egress/egress-gateway/) ·
  [Multicluster](https://istio.io/latest/docs/setup/install/multicluster/)
- [Distributed tracing](https://istio.io/latest/docs/tasks/observability/distributed-tracing/) ·
  [Access logs](https://istio.io/latest/docs/tasks/observability/logs/access-log/) ·
  [Standard metrics](https://istio.io/latest/docs/reference/config/metrics/)

## Gateway API, Envoy, cert-manager, inference

- [Gateway API](https://gateway-api.sigs.k8s.io/) ·
  [Gateway](https://gateway-api.sigs.k8s.io/reference/api-types/gateway/) ·
  [HTTPRoute](https://gateway-api.sigs.k8s.io/reference/api-types/httproute/) ·
  [TLS guide](https://gateway-api.sigs.k8s.io/guides/tls/) ·
  [ReferenceGrant](https://gateway-api.sigs.k8s.io/reference/api-types/referencegrant/)
- [Envoy Gateway](https://gateway.envoyproxy.io/docs/) ·
  [Proxy access logs](https://gateway.envoyproxy.io/docs/tasks/observability/proxy-accesslog/)
- [Envoy access log reference](https://www.envoyproxy.io/docs/envoy/latest/configuration/observability/access_log/usage)
- [cert-manager docs](https://cert-manager.io/docs/) ·
  [Gateway usage](https://cert-manager.io/docs/usage/gateway/) ·
  [Troubleshooting](https://cert-manager.io/docs/troubleshooting/)
- [Gateway API Inference Extension](https://gateway-api-inference-extension.sigs.k8s.io/) ·
  [releases](https://github.com/kubernetes-sigs/gateway-api-inference-extension/releases)

## Others

- [MetalLB](https://metallb.io/configuration/) · [kube-router](https://www.kube-router.io/docs/user-guide/) ·
  [Multus](https://github.com/k8snetworkplumbingwg/multus-cni) · [CNI plugins](https://www.cni.dev/plugins/current/)
- [Calico docs](https://docs.tigera.io/calico/latest/about/)
- [CoreDNS plugins](https://coredns.io/plugins/) · [Prometheus querying](https://prometheus.io/docs/prometheus/latest/querying/basics/) ·
  [Jaeger](https://www.jaegertracing.io/docs/latest/) · [tcpdump man page](https://www.tcpdump.org/manpages/tcpdump.1.html) ·
  [tc-netem](https://man7.org/linux/man-pages/man8/tc-netem.8.html) · [iptables](https://man7.org/linux/man-pages/man8/iptables.8.html)

## Practice environment

- [Killercoda Kubernetes playgrounds](https://killercoda.com/playgrounds) (2-node kubeadm cluster, this repo's target)
- [Killer Shell exam simulators](https://killer.sh/) (no CKNE simulator was available when the beta reports were written)
- The Linux Foundation offers a CKNE training course (see the program page above)

## Versions pinned by these labs

Cilium 1.20.5 (CLI v0.20.3) · Envoy Gateway v1.10.0 · Istio 1.32.0 · cert-manager v1.21.3 · MetalLB v0.16.2 ·
Gateway API Inference Extension v1.6.2 · Multus v4.3.2 · Jaeger 2.23.0 · Prometheus v3.5.0.
Override with environment variables (see `lib/common.sh`) if you want to try other versions.
