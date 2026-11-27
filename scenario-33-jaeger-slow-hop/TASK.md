# Scenario 33 – Jaeger: find the slow hop and the error

**Domain 5 – Observability** · Session: A or B · Time: ~10 min

## Context

Every checkout request goes through four services in a chain:

```
frontend → cart → pricing → inventory
```

Users say checkout is slow, and some requests fail. A trace generator sends traces to
**Jaeger** in namespace `tracing`. In every trace **one service is slow** and in some
traces **another service reports an error**.

Jaeger UI: NodePort **30686** on any node, or

```bash
kubectl -n tracing port-forward svc/jaeger 16686:16686      # then open http://localhost:16686
```

> Give the generator about **1 minute** to produce traces.

## Task

1. In the Jaeger UI, find which **service adds the latency**: open slow traces, sort by
   longest, and look at the span timeline (a long span with **short children**, or a long
   span at the end of the chain). Write the **service name** into
   `/opt/answers/slow-service.txt`.
2. Find the service whose spans carry **`error=true`** (use the Tags filter
   `error=true`). Write its **service name** into `/opt/answers/error-service.txt`.

## Test AFTER fix

```bash
cat /opt/answers/slow-service.txt /opt/answers/error-service.txt
```

## Hints

- Service dropdown = `frontend`, then **Find Traces**. Sort: *Longest First*.
- Compare a **fast** trace and a **slow** trace to see which span grows.
- Tags search: `error=true` or `http.status_code=503`.
- Docs: <https://www.jaegertracing.io/docs/latest/frontend-ui/>
