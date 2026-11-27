# Scenario 09 – Service without a selector + manual EndpointSlice

**Domain 2 – Service Networking and DNS** · Session: Any playground · Time: ~8 min

## Context

An "external API" runs **outside the Pods**: a plain web server on **node01**, TCP
**8088**. It is not a Pod, so no Service selector can find it. Namespace `ext` has a
test Pod `toolbox` (curl).

## Task

In namespace `ext`:

1. Create a Service named **`external-api`** with **no selector**. Port **`80`** (named
   `http`) → targetPort **`8088`**.
2. Create an **EndpointSlice** named **`external-api-1`** that sends the Service to the
   **InternalIP of node01** on port 8088 (`addressType: IPv4`).
3. From the `toolbox` Pod, `curl http://external-api` must return `external-api-ok`.

## Test AFTER fix

```bash
kubectl -n ext get svc external-api
kubectl -n ext get endpointslices -l kubernetes.io/service-name=external-api
kubectl -n ext exec toolbox -- curl -s -m3 http://external-api
```

## Hints

- Kubernetes does **not** create EndpointSlices for a Service without a selector.
- The EndpointSlice needs the label `kubernetes.io/service-name: external-api`, and its
  port **name** must match the Service port name.
- `kubectl get node node01 -o wide` for the IP.
- Docs: <https://kubernetes.io/docs/concepts/services-networking/service/#services-without-selectors>
