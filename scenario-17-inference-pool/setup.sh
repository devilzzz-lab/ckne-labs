#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
need_cluster
echo "=== Setting up Scenario 17: Inference Gateway ==="
ensure_envoy_gateway
if ! kubectl get crd inferencepools.inference.networking.k8s.io >/dev/null 2>&1; then
  log "Installing Inference Extension CRDs $GIE_VERSION"
  kubectl apply -f "https://github.com/kubernetes-sigs/gateway-api-inference-extension/releases/download/${GIE_VERSION}/manifests.yaml" >/dev/null
fi
kubectl wait --for=condition=Established crd/inferencepools.inference.networking.k8s.io --timeout=60s >/dev/null

kubectl delete ns inference --ignore-not-found --wait=true >/dev/null 2>&1 || true
kubectl create ns inference >/dev/null
kubectl -n inference apply -f - >/dev/null <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata: {name: vllm-llama}
spec:
  replicas: 3
  selector: {matchLabels: {app: vllm-llama}}
  template:
    metadata: {labels: {app: vllm-llama}}
    spec:
      containers:
      - {name: sim, image: "hashicorp/http-echo:1.0", args: ["-listen=:8000", "-text=model-server"], ports: [{containerPort: 8000}]}
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: llama-epp}
spec:
  replicas: 1
  selector: {matchLabels: {app: llama-epp}}
  template:
    metadata: {labels: {app: llama-epp}}
    spec:
      containers:
      - {name: epp, image: "hashicorp/http-echo:1.0", args: ["-listen=:9002", "-text=epp-standin"], ports: [{containerPort: 9002}]}
---
apiVersion: v1
kind: Service
metadata: {name: llama-epp}
spec:
  selector: {app: llama-epp}
  ports: [{name: grpc-ext-proc, port: 9002, targetPort: 9002}]
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata: {name: inference-gw}
spec:
  gatewayClassName: eg
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    allowedRoutes: {namespaces: {from: Same}}
EOF
kubectl -n inference rollout status deploy/vllm-llama --timeout=120s >/dev/null
kubectl -n inference rollout status deploy/llama-epp --timeout=120s >/dev/null
echo "Served inference API: $(kubectl api-resources --api-group=inference.networking.k8s.io -o name | tr '\n' ' ')"
echo "=== Setup complete. See TASK.md ==="
