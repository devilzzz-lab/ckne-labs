# Scenario 17 – Inference Gateway: InferencePool routing

**Domain 3 – Advanced Traffic Management** · Session: Any playground · Time: ~10 min

## Context

LLM servers are a poor fit for round-robin load balancing, because every replica has its
own queue and KV-cache state. The **Gateway API Inference Extension** adds an
**InferencePool** (a pool of model-server Pods) and an **Endpoint Picker (EPP)** that
chooses the best Pod per request.

Namespace `inference` already has:

| Object | Detail |
|--------|--------|
| Deployment `vllm-llama` | model-server Pods, label **`app=vllm-llama`**, listening on **8000** (a stand-in server, no GPU needed) |
| Service `llama-epp` | the endpoint picker, port **9002** |
| Gateway `inference-gw` | class `eg`, HTTP listener on port 80 |
| CRDs | the Inference Extension CRDs are installed |

> This lab checks your **configuration**. The stand-in servers and EPP do not do real
> inference scheduling.

## Task

1. Create an **InferencePool** named **`llama-pool`** in `inference` that selects the
   Pods with `app=vllm-llama`, targets port **8000**, and uses the endpoint picker
   Service **`llama-epp`** on port **9002**.
2. Create an **HTTPRoute** named **`llm-route`** attached to Gateway `inference-gw` that
   sends **`POST`** requests with path prefix **`/v1/completions`** to the InferencePool
   `llama-pool` (the pool is the `backendRef`, not a Service). The backendRef must name
   `group: inference.networking.k8s.io`, `kind: InferencePool` and `name: llama-pool`.

## Test AFTER fix

```bash
kubectl api-resources | grep -i inference
kubectl explain inferencepool.spec
kubectl -n inference get inferencepool llama-pool -o yaml
kubectl -n inference get httproute llm-route -o yaml
```

## Hints

- Use the API version the cluster serves: `kubectl api-resources | grep -i inferencepool`.
- `backendRefs` entries need `group`, `kind`, `name` for a non-Service backend.
- Docs: <https://gateway-api-inference-extension.sigs.k8s.io/> and
  <https://gateway-api-inference-extension.sigs.k8s.io/api-types/inferencepool/>
