# Scenario 21 – Istio: registry-only egress control

**Domain 3 – Advanced Traffic Management** · Session: **A (Calico)** · Time: ~12 min

## Context

Istio (ambient profile, so `istiod` is available) is installed. Namespace `egress-lab`
has sidecar injection enabled and a Pod `curl-client` (it has an Istio sidecar).

By default an Istio sidecar lets traffic to **any** external host through. The security
team wants the opposite: **only explicitly registered external hosts** are reachable.

```bash
kubectl -n egress-lab exec curl-client -c curl -- curl -s -o /dev/null -w '%{http_code}\n' -m5 http://example.com    # 200 today
kubectl -n egress-lab exec curl-client -c curl -- curl -s -o /dev/null -w '%{http_code}\n' -m5 http://example.org    # 200 today
```

## Task

In namespace `egress-lab`:

1. Create a **`Sidecar`** resource named **`default`** that sets
   `outboundTrafficPolicy.mode: REGISTRY_ONLY`.
2. Register **`example.com`** as an allowed external service with a **`ServiceEntry`**
   named **`ext-example`** (port 80, protocol HTTP, `location: MESH_EXTERNAL`,
   `resolution: DNS`).
3. Result: `http://example.com` → **200**, `http://example.org` → **502** (blocked by the
   sidecar).

## Test AFTER fix

```bash
kubectl -n egress-lab exec curl-client -c curl -- curl -s -o /dev/null -w '%{http_code}\n' -m5 http://example.com
kubectl -n egress-lab exec curl-client -c curl -- curl -s -o /dev/null -w '%{http_code}\n' -m5 http://example.org
istioctl proxy-config cluster curl-client.egress-lab | grep -E 'example|BlackHole|Passthrough'
```

## Hints

- APIs: `networking.istio.io/v1` `Sidecar` and `ServiceEntry`.
- Docs: <https://istio.io/latest/docs/tasks/traffic-management/egress/egress-control/>
- Stretch (not checked): route example.com through an **egress gateway** using
  `Gateway` + `VirtualService` + `DestinationRule`:
  <https://istio.io/latest/docs/tasks/traffic-management/egress/egress-gateway/>
