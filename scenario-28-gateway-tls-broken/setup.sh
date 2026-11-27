#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
need_cluster
echo "=== Setting up Scenario 28: Gateway TLS troubleshooting ==="
ensure_envoy_gateway
ensure_cert_manager
kubectl apply -f - >/dev/null <<'EOF'
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata: {name: selfsigned}
spec:
  selfSigned: {}
EOF
kubectl delete ns store --ignore-not-found --wait=true >/dev/null 2>&1 || true
kubectl create ns store >/dev/null
kubectl -n store apply -f - >/dev/null <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata: {name: store}
spec:
  replicas: 1
  selector: {matchLabels: {app: store}}
  template:
    metadata: {labels: {app: store}}
    spec:
      containers:
      - {name: app, image: "hashicorp/http-echo:1.0", args: ["-listen=:8080", "-text=store-secure"], ports: [{containerPort: 8080}]}
---
apiVersion: v1
kind: Service
metadata: {name: store}
spec:
  selector: {app: store}
  ports: [{port: 80, targetPort: 8080}]
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata: {name: store-cert}
spec:
  secretName: store-tls
  dnsNames: ["store.example.com"]
  issuerRef: {name: selfsign, kind: ClusterIssuer}
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata: {name: store-gw}
spec:
  gatewayClassName: eg
  listeners:
  - name: https
    protocol: HTTPS
    port: 443
    hostname: store.example.com
    tls:
      mode: Terminate
      certificateRefs:
      - {kind: Secret, name: store-tls-cert}
    allowedRoutes: {namespaces: {from: Same}}
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: {name: store}
spec:
  parentRefs:
  - {name: store-gw, sectionName: htps}
  hostnames: ["store.example.com"]
  rules:
  - backendRefs:
    - {name: store, port: 80}
EOF
kubectl -n store rollout status deploy/store --timeout=120s >/dev/null
echo "=== Setup complete. See TASK.md ==="
