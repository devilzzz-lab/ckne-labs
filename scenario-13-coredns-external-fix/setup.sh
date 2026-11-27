#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
need_cluster
echo "=== Setting up Scenario 13: CoreDNS fix external lookups ==="
coredns_backup
BROKEN=$(sed -E 's#forward \. [^{]+#forward . 10.255.255.1 #' "$STATE_DIR/Corefile.orig")
kubectl -n kube-system create cm coredns --from-literal=Corefile="$BROKEN" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n kube-system rollout restart deploy coredns >/dev/null
kubectl -n kube-system rollout status deploy coredns --timeout=120s >/dev/null

kubectl delete ns dns-fix --ignore-not-found --wait=true >/dev/null 2>&1 || true
kubectl create ns dns-fix >/dev/null
ensure_toolbox dns-fix
wait_ready dns-fix pod/toolbox
echo "=== Setup complete. See TASK.md ==="
