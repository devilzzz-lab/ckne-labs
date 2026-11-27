#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
need_cluster
echo "=== Setting up Scenario 16: Gateway API troubleshooting ==="
ensure_envoy_gateway
kubectl delete ns blog --ignore-not-found --wait=true >/dev/null 2>&1 || true
kubectl create ns blog >/dev/null
kubectl -n blog apply -f - >/dev/null <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata: {name: blog}
spec:
  replicas: 1
  selector: {matchLabels: {app: blog}}
  template:
    metadata: {labels: {app: blog}}
    spec:
      containers:
      - {name: app, image: "hashicorp/http-echo:1.0", args: ["-listen=:8080", "-text=blog-v1"], ports: [{containerPort: 8080}]}
---
apiVersion: v1
kind: Service
metadata: {name: blog}
spec:
  selector: {app: blog}
  ports: [{port: 80, targetPort: 8080}]
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata: {name: blog-gw}
spec:
  gatewayClassName: eg
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    hostname: blog.example.com
    allowedRoutes: {namespaces: {from: Same}}
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: {name: blog}
spec:
  parentRefs:
  - name: blog-gateway
  hostnames: ["www.blog.example.org"]
  rules:
  - matches: [{path: {type: PathPrefix, value: /}}]
    backendRefs:
    - {name: blog, port: 8080}
EOF
kubectl -n blog rollout status deploy/blog --timeout=120s >/dev/null
# remember the original Gateway/Service so check.sh can prove they were not edited
state_set s16-gw-gen "$(kubectl -n blog get gateway blog-gw -o jsonpath='{.metadata.generation}')"
state_set s16-svc-port "$(kubectl -n blog get svc blog -o jsonpath='{.spec.ports[0].port}')"
echo "=== Setup complete. See TASK.md ==="
