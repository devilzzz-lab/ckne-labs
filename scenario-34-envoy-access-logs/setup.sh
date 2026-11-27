#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
need_cluster
echo "=== Setting up Scenario 34: Envoy access logs ==="
ensure_envoy_gateway
rm -f "$ANS_DIR"/agent.txt "$ANS_DIR"/client-ip.txt
BADUA="BruteBot/$((100 + RANDOM % 900))"
state_set s34-ua "$BADUA"

kubectl delete ns web --ignore-not-found --wait=true >/dev/null 2>&1 || true
kubectl create ns web >/dev/null
kubectl -n web apply -f - >/dev/null <<EOF
apiVersion: apps/v1
kind: Deployment
metadata: {name: api}
spec:
  replicas: 1
  selector: {matchLabels: {app: api}}
  template:
    metadata: {labels: {app: api}}
    spec:
      containers:
      - {name: app, image: "ealen/echo-server:0.9.2", ports: [{containerPort: 80}]}
---
apiVersion: v1
kind: Service
metadata: {name: api}
spec:
  selector: {app: api}
  ports: [{port: 80, targetPort: 80}]
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
    allowedRoutes: {namespaces: {from: Same}}
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: {name: api}
spec:
  parentRefs: [{name: web-gw}]
  rules:
  - backendRefs: [{name: api, port: 80}]
EOF
kubectl -n web rollout status deploy/api --timeout=120s >/dev/null

# Wait for the Envoy proxy Service, then start the traffic generators against it.
for i in $(seq 1 40); do GWSVC=$(gw_svc web web-gw); [ -n "$GWSVC" ] && break; sleep 3; done
[ -n "${GWSVC:-}" ] || die "Envoy proxy Service for web-gw did not appear"
URL="http://$GWSVC.envoy-gateway-system.svc.cluster.local"

gen() { # name, user-agent, path-with-query, sleep
kubectl -n web apply -f - >/dev/null <<EOF2
apiVersion: v1
kind: Pod
metadata: {name: $1, labels: {role: traffic}}
spec:
  containers:
  - name: c
    image: curlimages/curl:8.8.0
    command: ["sh", "-c", "while true; do curl -s -o /dev/null -m3 -A '$2' '$URL$3'; sleep $4; done"]
EOF2
}
gen client-browser   "Mozilla/5.0 (X11; Linux x86_64)"      "/api/login?echo_code=200" 1
gen client-probe     "kube-probe/1.37"                       "/healthz?echo_code=200"   2
gen client-scanner   "Nmap-Scripting-Engine/7"               "/admin?echo_code=403"     0.5
gen client-badlogin  "$BADUA"                                "/api/login?echo_code=401" 0.4
gen client-typo      "curl/8.5.0"                            "/api/login?echo_code=401" 4
for p in client-browser client-probe client-scanner client-badlogin client-typo; do wait_ready web pod/$p; done
echo "Traffic is flowing. The access logs fill up within a minute."
echo "=== Setup complete. See TASK.md ==="
