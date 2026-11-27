#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
need_cluster
echo "=== Setting up Scenario 27: cert-manager + Gateway ==="
ensure_envoy_gateway
ensure_cert_manager
kubectl delete clusterissuer selfsigned --ignore-not-found >/dev/null 2>&1 || true
kubectl delete ns secure --ignore-not-found --wait=true >/dev/null 2>&1 || true
kubectl create ns secure >/dev/null
kubectl -n secure apply -f - >/dev/null <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata: {name: app}
spec:
  replicas: 1
  selector: {matchLabels: {app: app}}
  template:
    metadata: {labels: {app: app}}
    spec:
      containers:
      - {name: app, image: "hashicorp/http-echo:1.0", args: ["-listen=:8080", "-text=app-secure"], ports: [{containerPort: 8080}]}
---
apiVersion: v1
kind: Service
metadata: {name: app}
spec:
  selector: {app: app}
  ports: [{port: 80, targetPort: 8080}]
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata: {name: secure-gw}
spec:
  gatewayClassName: eg
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    hostname: app.example.com
    allowedRoutes: {namespaces: {from: Same}}
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: {name: app}
spec:
  parentRefs:
  - name: secure-gw
  hostnames: ["app.example.com"]
  rules:
  - backendRefs:
    - {name: app, port: 80}
EOF
kubectl -n secure rollout status deploy/app --timeout=120s >/dev/null
echo "=== Setup complete. See TASK.md ==="
