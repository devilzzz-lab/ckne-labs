# Solution – Scenario 14: Service with no endpoints

## Step 1 – Walk the path

```bash
kubectl -n shop get endpointslices -l kubernetes.io/service-name=checkout
#   ENDPOINTS: <unset>                   <- selector matches nothing
kubectl -n shop get svc checkout -o jsonpath='{.spec.selector}{"\n"}'     # {"app":"checkouts"}
kubectl -n shop get pods --show-labels                                     # app=checkout
kubectl -n shop get svc checkout -o jsonpath='{.spec.ports}{"\n"}'         # targetPort 80, app listens on 8080
```

## Step 2 – Fix the Service

```bash
kubectl -n shop patch svc checkout --type=merge -p \
  '{"spec":{"selector":{"app":"checkout"},"ports":[{"port":8080,"targetPort":8080}]}}'
```

(`kubectl edit svc checkout` works too. With `patch` on `ports` the whole list is replaced,
which is what we want here.)

## Step 3 – Add the readiness probe

```bash
kubectl -n shop patch deploy checkout --type=json -p '[
  {"op":"add","path":"/spec/template/spec/containers/0/readinessProbe",
   "value":{"tcpSocket":{"port":8080},"periodSeconds":5}}]'
kubectl -n shop rollout status deploy/checkout
```

## Step 4 – Verify

```bash
kubectl -n shop get endpointslices -l kubernetes.io/service-name=checkout -o yaml | grep -A3 conditions
kubectl -n shop exec toolbox -- curl -s http://checkout:8080        # checkout-ok
```

## Why

Triage order for "Service has no healthy backends":

| Look at | Broken when |
|---------|-------------|
| EndpointSlice empty | selector ≠ Pod labels (or Pods in another namespace) |
| Endpoints present, `ready: false` | readiness probe failing (wrong port/path/timing) |
| `targetPort` vs `containerPort` | traffic sent to a port nothing listens on |
| App bound to `127.0.0.1` | reachable by `kubectl exec`, not through the Service |

Readiness controls the Service membership. Liveness restarts the container. Startup delays
both until the app has started.
