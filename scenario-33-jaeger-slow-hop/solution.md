# Solution – Scenario 33: Jaeger slow hop

## Step 1 – Open Jaeger

```bash
kubectl -n tracing port-forward svc/jaeger 16686:16686 &
# UI: http://localhost:16686   (or http://<node-ip>:30686)
```

## Step 2 – The slow service

1. **Service:** `frontend`, **Operation:** all, **Find Traces**.
2. Sort by **Longest First** and open the top trace. The timeline is a staircase:
   `frontend → cart → pricing → inventory`.
3. Every parent span contains its children. A span's **own time** is its duration minus
   its child's duration:

   | Span | Duration | Own time (duration − child) |
   |------|----------|------------------------------|
   | frontend | 860 ms | 10 ms (860 − 850) |
   | cart | 850 ms | 15 ms (850 − 835) |
   | pricing | 835 ms | **820 ms** (835 − 15) ← the slow one |
   | inventory | 15 ms | 15 ms (no child) |

   (Illustrative numbers.) The service with a large **own time** is the slow hop. A long **duration** alone proves nothing, because every parent includes its children. If the slow service is the last one (`inventory`), its span is long and has no child. Confirm it
   with a short trace, where the same span is small. The Jaeger **compare** view or
   **Trace statistics** (self time per service) shows the same thing.

```bash
echo pricing > /opt/answers/slow-service.txt       # the one YOU found
```

## Step 3 – The error

Tags box: `error=true` → **Find Traces**. Open a result: the red span with `error=true`
and `http.status_code=503`. Its **service name** is the answer.

```bash
echo inventory > /opt/answers/error-service.txt    # the one YOU found
```

## Why

- A **trace** is a tree of **spans**, one per hop. Each span has a service, a duration and
  tags (status, peer, upstream cluster) and a trace ID that ties the request together.
- Long parent + short children = time spent **in that service**. A gap between spans =
  network or queueing delay. Repeated child spans = retries.
- Compare a good and a bad trace to find what changed. Find failures with `error=true` or
  `http.status_code`.
- In Istio ambient, spans come from **waypoints and gateways** (L7). ztunnel is L4 and
  creates none. Applications must forward `traceparent` / `x-b3-*` headers or the trace
  breaks into pieces.
- Istio setup: `meshConfig.extensionProviders` (OpenTelemetry → Jaeger on 4317) plus a
  `Telemetry` resource with `tracing.providers` and `randomSamplingPercentage`.
