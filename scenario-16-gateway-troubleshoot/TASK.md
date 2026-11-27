# Scenario 16 – Gateway API: fix a broken route

**Domain 2 – Service Networking and DNS** · Session: Any playground · Time: ~10 min

## Context

Namespace `blog` contains:

- Deployment/Service `blog` (Service port **80**, app returns `blog-v1`)
- Gateway **`blog-gw`** with an HTTP listener `http` on port 80 for hostname
  **`blog.example.com`** (same-namespace routes allowed)
- HTTPRoute **`blog`**, which is **not working**

```bash
# via a port-forward to the Envoy Service of blog-gw:
curl -s -H 'Host: blog.example.com' localhost:8080/        # 404 or no response, expected: blog-v1
```

## Task

Fix the **HTTPRoute `blog`** so that `curl -H 'Host: blog.example.com' …/` returns
`blog-v1`. Do **not** change the Gateway or the Service. Find the problems from the
**status conditions** of the route.

## Test AFTER fix

```bash
kubectl -n blog describe httproute blog        # Accepted=True and ResolvedRefs=True
SVC=$(kubectl -n envoy-gateway-system get svc -l gateway.envoyproxy.io/owning-gateway-name=blog-gw -o name)
kubectl -n envoy-gateway-system port-forward $SVC 8080:80 &
curl -s -H 'Host: blog.example.com' localhost:8080/
```

## Hints

- `kubectl -n blog get httproute blog -o yaml` and read `status.parents[].conditions`.
- Compare names, hostnames and ports against the Gateway and the Service.
- Docs: <https://gateway-api.sigs.k8s.io/reference/api-types/httproute/#status>
