# Solution – Scenario 16: Gateway API troubleshooting

## Step 1 – Read the status, it names the problem

```bash
kubectl -n blog describe httproute blog
#   Parent Refs: name blog-gateway   <- there is no such Gateway
```

Fix problems one at a time and re-read the status after each fix.

| # | Symptom in status | Cause | Fix |
|---|-------------------|-------|-----|
| 1 | No `status.parents` at all, or `Accepted=False` / `NoMatchingParent` | `parentRefs.name: blog-gateway`, the Gateway is `blog-gw` | `name: blog-gw` |
| 2 | `Accepted=False`, reason `NoMatchingListenerHostname` | route host `www.blog.example.org` does not overlap the listener host `blog.example.com` | `hostnames: [blog.example.com]` |
| 3 | `ResolvedRefs=False`, reason `BackendNotFound` (or no endpoints) | `backendRefs.port: 8080`, but the **Service** port is `80` | `port: 80` |

## Step 2 – Apply the fix

```bash
kubectl -n blog patch httproute blog --type=merge -p '{
  "spec": {
    "parentRefs": [{"name": "blog-gw"}],
    "hostnames": ["blog.example.com"],
    "rules": [{"matches": [{"path": {"type": "PathPrefix", "value": "/"}}],
               "backendRefs": [{"name": "blog", "port": 80}]}]
  }}'
kubectl -n blog describe httproute blog | grep -B1 -A4 -E 'Accepted|ResolvedRefs'
```

## Step 3 – Verify

```bash
SVC=$(kubectl -n envoy-gateway-system get svc -l gateway.envoyproxy.io/owning-gateway-name=blog-gw -o name)
kubectl -n envoy-gateway-system port-forward $SVC 8080:80 &
curl -s -H 'Host: blog.example.com' localhost:8080/        # blog-v1
```

## Why

`backendRefs.port` is the **Service port**, not the container port. The Service then maps
it to `targetPort`. The status of the route tells you which **layer** is wrong:
listener/parent (Accepted), backend (ResolvedRefs), or the controller (look at the
`envoy-gateway` logs).
