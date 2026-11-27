# Solution – Scenario 17: Inference Gateway

## Step 1 – Check the API version the cluster serves

```bash
kubectl api-resources | grep -i inference
#   inferencepools   infpool   inference.networking.k8s.io/v1   true   InferencePool
kubectl explain inferencepool.spec
```

Early releases used `inference.networking.x-k8s.io/v1alpha2`. The GA kind is
`inference.networking.k8s.io/v1`. Always follow what `api-resources` shows.

## Step 2 – InferencePool + HTTPRoute

```bash
kubectl apply -f - <<'EOF'
apiVersion: inference.networking.k8s.io/v1
kind: InferencePool
metadata:
  name: llama-pool
  namespace: inference
spec:
  selector:
    matchLabels:
      app: vllm-llama
  targetPorts:
  - number: 8000
  endpointPickerRef:
    name: llama-epp
    port:
      number: 9002
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: llm-route
  namespace: inference
spec:
  parentRefs:
  - name: inference-gw
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /v1/completions
      method: POST
    backendRefs:
    - group: inference.networking.k8s.io
      kind: InferencePool
      name: llama-pool
EOF
```

## Step 3 – Verify

```bash
kubectl -n inference get inferencepool llama-pool -o yaml
kubectl -n inference describe httproute llm-route
```

On a real inference-capable gateway you would then send a completion:

```bash
curl -s http://$GW_IP/v1/completions -H 'Content-Type: application/json' \
  -d '{"model":"<model>","prompt":"Hello","max_tokens":20}'
```

## Why

- A normal Service balances per connection or per request, blind to the model state.
  The **Endpoint Picker** is called by the gateway for each request (ext-proc) and picks
  a Pod using live metrics: queue depth, KV-cache use, loaded LoRA adapters.
- `InferencePool` is the model-server equivalent of a Service. It is **the backend of an
  HTTPRoute**, referenced by `group` + `kind` + `name`.
- `endpointPickerRef.failureMode` defaults to `FailClose` (the request fails if the EPP
  is down). `FailOpen` forwards without scheduling.
- Typical failure causes: wrong `group/kind` in `backendRefs` (`ResolvedRefs=False`), wrong
  `selector` or `targetPorts` (traffic to wrong Pods), EPP Service/port wrong (500/503).
