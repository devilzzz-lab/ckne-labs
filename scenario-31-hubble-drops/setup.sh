#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
need_cluster
echo "=== Setting up Scenario 31: Hubble drops ==="
require_cilium
ensure_hubble_cli
if ! kubectl -n kube-system get deploy hubble-relay >/dev/null 2>&1; then
  log "Enabling Hubble (relay + UI)"
  cilium hubble enable --ui
  cilium status --wait --wait-duration 5m >/dev/null
fi
rm -f "$ANS_DIR"/dropped-source.txt "$ANS_DIR"/drop-reason.txt

apps=(app-a app-b app-c)
BLOCKED=${apps[$((RANDOM % 3))]}
state_set s31-blocked "$BLOCKED"
ALLOWED=(); for a in "${apps[@]}"; do [ "$a" != "$BLOCKED" ] && ALLOWED+=("$a"); done

kubectl delete ns finance --ignore-not-found --wait=true >/dev/null 2>&1 || true
kubectl create ns finance >/dev/null
kubectl -n finance apply -f - >/dev/null <<EOF
apiVersion: apps/v1
kind: Deployment
metadata: {name: db}
spec:
  replicas: 1
  selector: {matchLabels: {app: db}}
  template:
    metadata: {labels: {app: db}}
    spec:
      containers:
      - {name: db, image: "hashicorp/http-echo:1.0", args: ["-listen=:5432", "-text=db-ok"], ports: [{containerPort: 5432}]}
---
apiVersion: v1
kind: Service
metadata: {name: db}
spec:
  selector: {app: db}
  ports: [{port: 5432, targetPort: 5432}]
---
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata: {name: db-ingress}
spec:
  endpointSelector:
    matchLabels: {app: db}
  ingress:
  - fromEndpoints:
    - matchLabels: {app: ${ALLOWED[0]}}
    - matchLabels: {app: ${ALLOWED[1]}}
    toPorts:
    - ports: [{port: "5432", protocol: TCP}]
EOF
for a in "${apps[@]}"; do
kubectl -n finance apply -f - >/dev/null <<EOF
apiVersion: apps/v1
kind: Deployment
metadata: {name: $a}
spec:
  replicas: 1
  selector: {matchLabels: {app: $a}}
  template:
    metadata: {labels: {app: $a}}
    spec:
      containers:
      - name: c
        image: curlimages/curl:8.8.0
        command: ["sh", "-c", "while true; do curl -s -m2 http://db:5432 >/dev/null; sleep 2; done"]
EOF
done
for d in db app-a app-b app-c; do kubectl -n finance rollout status deploy/$d --timeout=120s >/dev/null; done
echo "(The blocked client is chosen at random. Find it with Hubble.)"
echo "=== Setup complete. See TASK.md ==="
