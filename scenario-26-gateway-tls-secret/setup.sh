#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
need_cluster
echo "=== Setting up Scenario 26: Gateway HTTPS with a TLS Secret ==="
ensure_envoy_gateway
mkdir -p /opt/certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /opt/certs/shop.key -out /opt/certs/shop.crt \
  -subj "/CN=shop.example.com" -addext "subjectAltName=DNS:shop.example.com" >/dev/null 2>&1
kubectl delete ns web --ignore-not-found --wait=true >/dev/null 2>&1 || true
kubectl create ns web >/dev/null
kubectl -n web apply -f - >/dev/null <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata: {name: shop}
spec:
  replicas: 1
  selector: {matchLabels: {app: shop}}
  template:
    metadata: {labels: {app: shop}}
    spec:
      containers:
      - {name: app, image: "hashicorp/http-echo:1.0", args: ["-listen=:8080", "-text=shop-secure"], ports: [{containerPort: 8080}]}
---
apiVersion: v1
kind: Service
metadata: {name: shop}
spec:
  selector: {app: shop}
  ports: [{port: 80, targetPort: 8080}]
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata: {name: web-gw}
spec:
  gatewayClassName: eg
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    hostname: shop.example.com
    allowedRoutes: {namespaces: {from: Same}}
EOF
kubectl -n web rollout status deploy/shop --timeout=120s >/dev/null
echo "Cert: $(openssl x509 -in /opt/certs/shop.crt -noout -subject)"
echo "=== Setup complete. See TASK.md ==="
