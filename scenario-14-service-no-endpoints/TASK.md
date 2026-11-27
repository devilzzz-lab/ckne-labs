# Scenario 14 – Service with no endpoints + readiness probe

**Domain 2 – Service Networking and DNS** · Session: A or B · Time: ~8 min

## Context

In namespace `shop`, Deployment `checkout` (2 replicas, image `hashicorp/http-echo:1.0`,
listens on **8080**) is `Running`, but this fails:

```bash
kubectl -n shop exec toolbox -- curl -s -m3 http://checkout:8080
```

The Service `checkout` exists (port `8080`).

## Task

1. Find out why the Service has no working backends and fix the **Service** (do not
   change the Pod labels or the application port).
2. Add a **TCP readiness probe** on port **8080** (`periodSeconds: 5`) to the container
   in Deployment `checkout`.
3. Both replicas must be listed as **ready** endpoints, and `curl http://checkout:8080`
   must return `checkout-ok`.

## Test AFTER fix

```bash
kubectl -n shop get endpointslices -l kubernetes.io/service-name=checkout
kubectl -n shop exec toolbox -- curl -s -m3 http://checkout:8080
```

## Hints

- `kubectl -n shop get endpointslices`, `get pods --show-labels`, `get svc checkout -o yaml`.
- Two separate mistakes: what the Service **selects**, and where it **sends** the traffic.
- Docs: <https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/>
  and <https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/>
