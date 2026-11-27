# Domain 5: Observability (15%)

Official competencies:
1. Analyzing network health using metrics
2. Troubleshooting end-to-end network performance with tracing
3. Auditing traffic with logs

Labs: **31** Hubble drops · **32** Prometheus failing Pod · **33** Jaeger slow hop · **34** Envoy access logs

In the exam the Prometheus, Hubble and Jaeger **UIs are already running**. Tasks give you a broken system and ask
*where* it fails, *which* backend is unhealthy, or *who* sent the traffic. Practise **navigating the UIs and
interpreting data**, then turn the finding into a Kubernetes action. Do not memorise metric names or long PromQL.

---

## 1. Hubble: network flows  (lab 31)

Hubble records the flows Cilium handles: source/destination identity, **verdict** (`FORWARDED`, `DROPPED`, `AUDIT`),
drop reason, and (through the L7 proxy) HTTP and DNS details.

```bash
cilium hubble enable --ui
cilium hubble port-forward &         # Hubble Relay on localhost:4245
hubble status
cilium hubble ui                     # service map (or port-forward svc/hubble-ui)
kubectl -n kube-system exec ds/cilium -- hubble observe ...      # agent-local alternative
```

Filters you will use:

```bash
hubble observe -n shop --last 50 ; hubble observe -n shop --follow
hubble observe --verdict DROPPED
hubble observe --verdict DROPPED -o json | jq -r '.flow.drop_reason_desc' | sort | uniq -c
hubble observe --from-pod shop/frontend-7d9 --to-pod shop/api-5c8
hubble observe --from-label app=frontend --to-label app=api
hubble observe --to-service shop/api
hubble observe --port 8080 --protocol tcp
hubble observe --protocol http --http-status 5+ ; hubble observe --protocol http --http-path /checkout
hubble observe --protocol dns
hubble observe --type policy-verdict
hubble observe --tcp-flags RST
```

| Drop reason (text / JSON enum) | Typical cause |
|--------------------------------|---------------|
| `Policy denied` / `POLICY_DENIED` | no policy allows this identity/port (Domain 4) |
| `Policy denied by denylist` / `POLICY_DENY` | explicit deny rule |
| `Stale or unroutable IP` | endpoint gone (Pod restarted) |
| `No mapping for NAT masquerade` / `Unknown L3 target address` | routing or masquerading misconfigured |
| `Service backend not found` | Service has no ready endpoints |

L7 fields (method, path, status) only appear when traffic goes through Cilium's proxy (an L7 policy applies).
The UI: pick the namespace, the service map shows edges, red/dropped flows point at the broken hop, click a flow for
identity, labels and reason.

Docs: [Hubble](https://docs.cilium.io/en/stable/observability/hubble/) ·
[Hubble CLI](https://docs.cilium.io/en/stable/observability/hubble/hubble-cli/) ·
[Setup](https://docs.cilium.io/en/stable/observability/hubble/setup/)

---

## 2. Prometheus: network health metrics  (lab 32)

UI **Graph** tab or the API:

```bash
curl -s 'http://<prom>:9090/api/v1/query' --data-urlencode 'query=up == 0' | jq '.data.result[].metric'
```

Start broad (which service), then narrow (which workload), then which Pod. Useful queries (names depend on installed exporters,
so check what exists with the metrics explorer or `{__name__=~"hubble.*"}`):

```promql
up == 0
sum by (reason) (rate(hubble_drop_total[5m]))
sum by (destination_workload) (rate(hubble_http_requests_total{status=~"5.."}[5m]))
sum by (destination_service) (rate(istio_requests_total{response_code=~"5.."}[5m]))
histogram_quantile(0.99, sum by (le, destination_service) (rate(istio_request_duration_milliseconds_bucket[5m])))
sum by (envoy_cluster_name) (rate(envoy_cluster_upstream_rq_xx{envoy_response_code_class="5"}[5m]))
envoy_cluster_membership_healthy < envoy_cluster_membership_total
sum by (rcode) (rate(coredns_dns_responses_total{rcode=~"SERVFAIL|NXDOMAIN"}[5m]))
increase(kube_pod_container_status_restarts_total[15m]) > 0
```

Finding the bad backend:

1. Group errors/latency by service (`sum by (destination_service)`).
2. Split that service by workload, then `by (pod)`.
3. Compare Pods. **One outlier** = bad Pod/node/probe. **All bad** = shared dependency, policy or config.
4. Confirm with `kubectl get endpointslices`, Pod logs and Hubble flows to that Pod.

PromQL basics: `rate()` on counters over a window of several scrape intervals; `increase()` = total over the window;
`sum by (label)` aggregates; ratios divide two `sum by` vectors with the same labels.

Docs: [Querying basics](https://prometheus.io/docs/prometheus/latest/querying/basics/) ·
[Functions](https://prometheus.io/docs/prometheus/latest/querying/functions/) ·
[Operators](https://prometheus.io/docs/prometheus/latest/querying/operators/) ·
[Hubble metrics](https://docs.cilium.io/en/stable/observability/metrics/) ·
[Istio standard metrics](https://istio.io/latest/docs/reference/config/metrics/)

---

## 3. Jaeger: end-to-end tracing  (lab 33)

A **trace** is a tree of **spans**, one per hop. A span has a service, a duration and tags (HTTP status, peer address,
upstream cluster, `error`). All spans of one request share a trace ID.

Reading a trace to find the slow hop:

1. Service = entry point (gateway/frontend) → **Find Traces**. Sort **Longest First**. Filter with `Min Duration` or
   Tags (`error=true`, `http.status_code=503`).
2. Open a trace. A **long parent with short children** means the time is spent **in that service**. A **gap** between spans
   means network or queueing delay. **Repeated children** are retries. `error=true` spans show where it failed.
3. A span's own time = its duration − its child's duration.
4. Compare a fast trace and a slow trace (the **Compare** view). Use span tags (`upstream_cluster`, `peer.address`) to find the
   Pod or node, then confirm with metrics or `tcpdump`.

How traces reach Jaeger with Istio: an OpenTelemetry provider in `meshConfig.extensionProviders`
(`opentelemetry` → `jaeger-collector:4317`) and a `Telemetry` resource with `tracing.providers` and
`randomSamplingPercentage`. In **ambient** mode spans come from **waypoints and gateways** (L7). ztunnel is L4 and makes
none. Applications must forward `traceparent` / `x-b3-*` headers, or traces end after one hop.

Docs: [Jaeger UI](https://www.jaegertracing.io/docs/latest/frontend-ui/) ·
[Jaeger getting started](https://www.jaegertracing.io/docs/latest/getting-started/) ·
[Istio distributed tracing](https://istio.io/latest/docs/tasks/observability/distributed-tracing/) ·
[OpenTelemetry](https://opentelemetry.io/docs/)

---

## 4. Auditing traffic with logs  (lab 34)

### Envoy Gateway proxy access logs

One Envoy Deployment per Gateway runs in `envoy-gateway-system`. Access logs go to the **`envoy`** container's stdout.

```bash
SEL=gateway.envoyproxy.io/owning-gateway-name=web-gw
kubectl -n envoy-gateway-system get pods -l $SEL
kubectl -n envoy-gateway-system logs -l $SEL -c envoy --tail=-1            # data plane
kubectl -n envoy-gateway-system logs deploy/envoy-gateway                  # control plane / translation
```

Fields: `x-envoy-origin-path`, `method`, `response_code`, `response_flags`, `user-agent`, `x-forwarded-for`,
`downstream_remote_address`, `upstream_host`, `duration`.

```bash
LOGS=$(kubectl -n envoy-gateway-system logs -l $SEL -c envoy --tail=-1)
echo "$LOGS" | jq -R -r 'fromjson? | select((."x-envoy-origin-path"//"")|startswith("/api/login"))
                         | select((.response_code|tonumber)>=400) | ."user-agent"' | sort | uniq -c | sort -rn
echo "$LOGS" | grep '/api/login' | grep -o '"user-agent":"[^"]*"' | sort | uniq -c | sort -rn     # no jq
```

Count carefully: filter on **path and status** together, then `sort | uniq -c | sort -rn`. Behind a load balancer the real
client is in `x-forwarded-for`.

### `response_flags` (why Envoy failed a request)

| Flag | Meaning |
|------|---------|
| `UH` | no healthy upstream (503) |
| `UF` | upstream connection failure (503) |
| `UT` | upstream timeout (504) |
| `NR` | no route (404) |
| `URX` | retry limit reached |
| `UAEX` | external authorization denied it |
| `RL` | rate limited (429) |
| `DC` | downstream client closed |

### Other logs

| Component | Command | Gives |
|-----------|---------|-------|
| Istio waypoint | `kubectl -n <ns> logs deploy/waypoint` | L7 access log (enable with Telemetry `accessLogging`) |
| ztunnel | `kubectl -n istio-system logs -l app=ztunnel` | L4 connections, identities, policy denials |
| Cilium agent | `kubectl -n kube-system logs ds/cilium` | datapath, policy, BGP errors |
| CoreDNS | `kubectl -n kube-system logs -l k8s-app=kube-dns` | query log (`log` plugin), upstream errors |
| Hubble | `hubble observe -o json` | per-flow audit trail with verdicts |
| Kubernetes audit | API server audit log | who changed what in the API |

Docs: [Envoy Gateway access logs](https://gateway.envoyproxy.io/docs/tasks/observability/proxy-accesslog/) ·
[Envoy access log format / flags](https://www.envoyproxy.io/docs/envoy/latest/configuration/observability/access_log/usage) ·
[Istio access logs](https://istio.io/latest/docs/tasks/observability/logs/access-log/) ·
[Kubernetes auditing](https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/)

---

## 5. Putting it together

```text
symptom
 |- which service?   -> Prometheus: error rate / latency by service
 |- which hop?       -> Jaeger: longest span, gaps, retries
 |- dropped?         -> Hubble: --verdict DROPPED + reason
 |- who / which path -> Envoy access logs: path, status, user-agent, client IP
 '- packet proof     -> tcpdump on the node / Pod interface (Domain 1)
```

1. **Scope:** one client, one service or everything? One node or all?
2. **Layer:** a *timeout* = L3/L4 (policy, routing, encryption). A *4xx/5xx* = L7 (policy, route, backend).
3. **Locate:** pick the tool that answers that layer's question.
4. **Fix and verify:** re-run the same query/command and confirm the symptom is gone.

---

## Checklist

- [ ] List dropped flows in a namespace with Hubble and read the drop reasons
- [ ] Spot a broken edge in the Hubble UI service map
- [ ] Filter flows by Pod, label, port, HTTP status and DNS
- [ ] In Prometheus find the service with the highest error rate and narrow it to one Pod
- [ ] Open a trace in Jaeger and name the hop that adds latency, and the one that errors
- [ ] Read Envoy access logs and explain a `response_flags` value
- [ ] For one URL path, find the user agent and client IP behind the failing requests
- [ ] Follow a denied request through ztunnel / waypoint logs
