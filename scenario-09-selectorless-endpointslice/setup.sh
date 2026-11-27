#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
need_cluster
echo "=== Setting up Scenario 09: Service without selector ==="
ensure_pkg python3
n1 'mkdir -p /srv/ckne-ext && echo external-api-ok > /srv/ckne-ext/index.html
    systemctl stop ckne-ext 2>/dev/null; systemctl reset-failed ckne-ext 2>/dev/null
    systemd-run --unit=ckne-ext --quiet python3 -m http.server 8088 --bind 0.0.0.0 -d /srv/ckne-ext'
kubectl delete ns ext --ignore-not-found --wait=true >/dev/null 2>&1 || true
kubectl create ns ext >/dev/null
ensure_toolbox ext
wait_ready ext pod/toolbox
N1IP=$(node_ip node01)
if tbx ext toolbox curl -s -m4 "http://$N1IP:8088" | grep -q external-api-ok; then log "External server on node01:8088 is reachable from Pods."; else warn "Could not reach node01:8088 from a Pod."; fi
echo "node01 InternalIP: $N1IP"
echo "=== Setup complete. See TASK.md ==="
