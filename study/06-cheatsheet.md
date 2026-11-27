# CKNE command cheatsheet

One-line reminders. Details and YAML are in the domain notes.

## kubectl essentials

```bash
export do="--dry-run=client -o yaml" now="--force --grace-period=0"
kubectl explain <res>.<field> --recursive | less
kubectl api-resources | grep -i <word>
kubectl get svc,endpointslices -n <ns>
kubectl get endpointslices -l kubernetes.io/service-name=<svc> -o wide
kubectl get pod -o wide --show-labels
kubectl describe <res> <name>                 # conditions + events
kubectl run t --rm -it --image=busybox:1.36 --restart=Never -- nslookup <name>
kubectl run t --rm -it --image=nicolaka/netshoot --restart=Never -- bash
kubectl debug -it <pod> --image=nicolaka/netshoot --target=<ctr>
kubectl replace --force -f pod.yaml           # immutable fields: delete + recreate
```

## Cilium

```bash
cilium status --wait
cilium config view | grep -i <key>
cilium upgrade --reuse-values --set <key>=<value>
kubectl -n kube-system rollout restart ds/cilium deploy/cilium-operator       # after EVERY config change
kubectl -n kube-system exec ds/cilium -- cilium-dbg status --verbose
kubectl -n kube-system exec ds/cilium -- cilium-dbg service list
kubectl -n kube-system exec ds/cilium -- cilium-dbg endpoint list
kubectl -n kube-system exec ds/cilium -- cilium-dbg policy get
kubectl -n kube-system exec ds/cilium -- cilium-dbg monitor --type drop
kubectl -n kube-system exec ds/cilium -- cilium-dbg bpf egress list
kubectl -n kube-system exec ds/cilium -- cilium-dbg encrypt status
cilium bgp peers ; cilium bgp routes advertised ipv4 unicast
cilium clustermesh status --wait ; cilium connectivity test
```

| Helm value | Feature |
|------------|---------|
| `kubeProxyReplacement=true` + `k8sServiceHost` / `k8sServicePort` | no kube-proxy, needs the real API server address |
| `bpf.masquerade=true` | SNAT in eBPF |
| `egressGateway.enabled=true` | egress gateway (needs KPR + BPF masquerade) |
| `bgpControlPlane.enabled=true` | BGP control plane |
| `encryption.enabled=true`, `encryption.type=wireguard` | Pod traffic encryption |
| `encryption.nodeEncryption=true` | also node-to-node |
| `cluster.name`, `cluster.id` | identity for Cluster Mesh |
| `gatewayAPI.enabled=true` | Cilium as Gateway API controller (install CRDs first) |
| `cni.exclusive=false` | coexist with Multus / Istio CNI |
| `hubble.relay.enabled=true`, `hubble.ui.enabled=true` | Hubble |
| `ipam.mode=kubernetes\|cluster-pool\|multi-pool` | IPAM |

## Hubble

```bash
cilium hubble port-forward &
hubble observe -n <ns> --verdict DROPPED
hubble observe --from-pod <ns>/<pod> --to-pod <ns>/<pod>
hubble observe --from-label app=a --to-label app=b
hubble observe --to-service <ns>/<svc>
hubble observe --protocol http --http-status 5+
hubble observe --protocol dns
hubble observe --type policy-verdict
hubble observe -o json | jq '.flow.drop_reason_desc'
```

## Istio ambient

```bash
istioctl install --set profile=ambient --skip-confirmation
kubectl label ns <ns> istio.io/dataplane-mode=ambient
istioctl waypoint apply -n <ns> --enroll-namespace --wait
istioctl ztunnel-config workloads
istioctl analyze -n <ns>
kubectl -n istio-system logs -l app=ztunnel | grep -iE "policy rejection|denied"
kubectl -n <ns> logs deploy/waypoint | grep -i rbac
```

| Need | Resource |
|------|----------|
| refuse non-mesh plaintext clients | `PeerAuthentication` `mtls.mode: STRICT` |
| allow/deny by identity and port (L4) | `AuthorizationPolicy` + `selector` (ztunnel) |
| allow/deny by method/path/header (L7) | `AuthorizationPolicy` + `targetRefs: Service` + waypoint |
| principal | `cluster.local/ns/<ns>/sa/<serviceaccount>` |
| block unknown external hosts (sidecar mode) | `Sidecar` `outboundTrafficPolicy: REGISTRY_ONLY` + `ServiceEntry` |

## Gateway API / Envoy Gateway

```bash
kubectl get gatewayclass,gateway,httproute -A
kubectl describe httproute <name>                  # status.parents[].conditions
kubectl -n envoy-gateway-system logs deploy/envoy-gateway
kubectl -n envoy-gateway-system logs -l gateway.envoyproxy.io/owning-gateway-name=<gw> -c envoy
GW_IP=$(kubectl -n <ns> get gateway <gw> -o jsonpath='{.status.addresses[0].value}')
curl -s --resolve <host>:80:$GW_IP http://<host>/<path>
curl -vk --resolve <host>:443:$GW_IP https://<host>/
openssl s_client -connect $GW_IP:443 -servername <host> </dev/null | openssl x509 -noout -subject -issuer -dates
kubectl api-resources | grep -i inference
```

## cert-manager

```bash
kubectl -n <ns> get certificate,certificaterequest
kubectl -n <ns> describe certificate <name>
kubectl -n cert-manager logs deploy/cert-manager
```

## Services, DNS

```bash
kubectl -n kube-system edit cm coredns
kubectl -n kube-system rollout restart deploy coredns
kubectl -n kube-system logs -l k8s-app=kube-dns
kubectl exec <pod> -- cat /etc/resolv.conf
iptables-save -t nat | grep <clusterIP> ; ipvsadm -Ln ; nft list ruleset
kubectl -n metallb-system get ipaddresspools,l2advertisements,bgppeers,bgpadvertisements
kubectl -n kube-system exec ds/kube-router -- gobgp neighbor
```

## Linux networking

```bash
ip -br addr ; ip route ; ip route get <ip> ; ip neigh ; ss -lntp
nsenter -t <pid> -n <cmd> ; crictl inspect <id> | jq .info.pid
tcpdump -i <if> -nn port <p>
tcpdump -i any -nn -c <count> -w /path/file.pcap dst port <p>
tcpdump -nn -r /path/file.pcap
iptables -t nat -L -n -v --line-numbers ; iptables-save | grep <ip> ; iptables -D <CHAIN> <n>
sysctl net.ipv4.ip_forward
tc qdisc show dev <if> ; tc qdisc del dev <if> root
curl -o /dev/null -s -w 'dns:%{time_namelookup} connect:%{time_connect} ttfb:%{time_starttransfer} total:%{time_total}\n' <url>
```

## PromQL

```promql
up == 0
sum by (reason) (rate(hubble_drop_total[5m]))
sum by (destination_service) (rate(istio_requests_total{response_code=~"5.."}[5m]))
histogram_quantile(0.99, sum by (le, destination_service) (rate(istio_request_duration_milliseconds_bucket[5m])))
sum by (rcode) (rate(coredns_dns_responses_total[5m]))
sum by (pod) (rate(app_http_requests_total{code="500"}[2m])) / sum by (pod) (rate(app_http_requests_total[2m]))
```

## Envoy `response_flags`

| Flag | Meaning |
|------|---------|
| `UH` | no healthy upstream (503) |
| `UF` | upstream connection failed (503) |
| `UT` | upstream timeout (504) |
| `NR` | no route (404) |
| `URX` | retry limit reached |
| `UAEX` | ext-auth denied |
| `RL` | rate limited (429) |
| `DC` | downstream closed |

## Status decoders

| Seen | Means |
|------|-------|
| curl timeout | L3/L4 drop (policy, routing, encryption) |
| HTTP 403 from Cilium | L7 policy rejected |
| HTTP 403 `RBAC: access denied` | Istio waypoint rejected |
| `Connection reset` | ztunnel L4 policy or STRICT mTLS |
| HTTP 404 from the gateway | no route/host match (`NR`) |
| HTTP 502 from a sidecar | `BlackHoleCluster` (REGISTRY_ONLY) |
| HTTP 503 `UH` | no healthy endpoints |
