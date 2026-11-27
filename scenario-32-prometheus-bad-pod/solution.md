# Solution – Scenario 32: Prometheus failing backend

## Step 1 – Open Prometheus

```bash
kubectl -n obs port-forward svc/prometheus 9090:9090 &
# UI: http://localhost:9090   (Killercoda: use the traffic/port menu, or the NodePort 30090)
```

Check targets first (**Status → Targets**): all 4 `orders-*` Pods must be `UP`. Or in the
query box: `up{job="orders"}`.

## Step 2 – Narrow it down: service → pod

```promql
# overall: is anything failing?
sum(rate(app_http_requests_total{code="500"}[2m]))

# per Pod: one stands out
sum by (pod) (rate(app_http_requests_total{code="500"}[2m]))

# per Pod as a ratio (this is the clearest view)
sum by (pod) (rate(app_http_requests_total{code="500"}[2m]))
  / sum by (pod) (rate(app_http_requests_total[2m]))
```

Three Pods show about 0, one shows about 0.6 (60 % errors). That Pod is the answer.

```bash
echo orders-2 > /opt/answers/bad-pod.txt        # the Pod YOU found
echo 'sum by (pod) (rate(app_http_requests_total{code="500"}[2m]))' > /opt/answers/query.txt
```

CLI equivalent:

```bash
curl -s 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=sum by (pod) (rate(app_http_requests_total{code="500"}[2m]))' \
  | jq -r '.data.result[] | "\(.metric.pod) \(.value[1])"'
```

## Why

- **Method:** find the service with errors, split by workload/pod, compare pods, and
  confirm with `kubectl logs`, `kubectl get endpointslices` and Hubble flows. One outlier
  usually means a bad Pod/node/probe. All pods bad usually means a shared dependency, policy or config.
- `rate()` needs a counter and a range window at least ~4× the scrape interval.
  `increase()` is the total over the window.
- Metric names differ per exporter. Use the **metrics explorer** or
  `{__name__=~"hubble.*"}` to see what exists before writing a query.
- Useful network queries from the exam blueprint: `sum by (reason) (rate(hubble_drop_total[5m]))`,
  `sum by (destination_service) (rate(istio_requests_total{response_code=~"5.."}[5m]))`,
  `histogram_quantile(0.99, sum by (le, destination_service) (rate(istio_request_duration_milliseconds_bucket[5m])))`.
