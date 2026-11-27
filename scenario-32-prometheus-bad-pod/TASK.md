# Scenario 32 – Prometheus: find the failing backend Pod

**Domain 5 – Observability** · Session: A or B · Time: ~10 min

## Context

Service `orders` in namespace `obs` is backed by a StatefulSet with **4 Pods**
(`orders-0` … `orders-3`). Users report that some requests fail. A **Prometheus** server
is running in `obs` and already scrapes the Pods. Each Pod exposes the counter:

```
app_http_requests_total{code="200"}   # successful requests
app_http_requests_total{code="500"}   # failed requests
```

Prometheus UI: NodePort **30090** on any node, or

```bash
kubectl -n obs port-forward svc/prometheus 9090:9090      # then open http://localhost:9090
```

> Prometheus needs about **1-2 minutes** after setup before rates are meaningful.

## Task

1. Use Prometheus to find the **one Pod** whose **5xx rate is clearly the highest**.
   Write the Pod name (for example `orders-2`) into `/opt/answers/bad-pod.txt`.
2. Write the **PromQL query** you used (one line) into `/opt/answers/query.txt`. It must
   use `rate(` and the metric `app_http_requests_total`.

## Test AFTER fix

```bash
cat /opt/answers/bad-pod.txt /opt/answers/query.txt
curl -s 'http://localhost:9090/api/v1/query' --data-urlencode "query=$(cat /opt/answers/query.txt)" | jq '.data.result'
```

## Hints

- Start broad: `up`, then `sum by (pod) (rate(app_http_requests_total[2m]))`, then split by `code`.
- The label that names the Pod is `pod`.
- Error ratio: `sum by (pod) (rate(app_http_requests_total{code="500"}[2m])) / sum by (pod) (rate(app_http_requests_total[2m]))`
- Docs: <https://prometheus.io/docs/prometheus/latest/querying/basics/>
  and <https://prometheus.io/docs/prometheus/latest/querying/functions/#rate>
