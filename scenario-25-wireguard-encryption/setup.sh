#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
need_cluster
echo "=== Setting up Scenario 25: WireGuard encryption ==="
require_cilium
if [ "$(cilium_cfg enable-wireguard)" = true ]; then
  warn "WireGuard is already enabled. Restart the playground to practise enabling it."
fi
rm -f "$ANS_DIR/wg-peers.txt"
n1 'modprobe wireguard 2>/dev/null; ip link add wgtest type wireguard 2>/dev/null && ip link del wgtest && echo "node01: WireGuard kernel support OK"' || warn "node01 may lack WireGuard kernel support"
kubectl delete ns enc --ignore-not-found --wait=true >/dev/null 2>&1 || true
kubectl create ns enc >/dev/null
kubectl -n enc apply -f - >/dev/null <<'EOF'
apiVersion: v1
kind: Pod
metadata: {name: server, labels: {app: server}}
spec:
  nodeSelector: {kubernetes.io/hostname: node01}
  containers:
  - {name: s, image: "hashicorp/http-echo:1.0", args: ["-listen=:8080", "-text=server-ok"], ports: [{containerPort: 8080}]}
---
apiVersion: v1
kind: Service
metadata: {name: server}
spec:
  selector: {app: server}
  ports: [{port: 8080, targetPort: 8080}]
---
apiVersion: v1
kind: Pod
metadata: {name: client}
spec:
  nodeSelector: {kubernetes.io/hostname: controlplane}
  tolerations: [{operator: Exists}]
  containers:
  - {name: c, image: "curlimages/curl:8.8.0", command: ["sleep", "infinity"]}
EOF
wait_ready enc pod/server; wait_ready enc pod/client
echo "=== Setup complete. See TASK.md ==="
