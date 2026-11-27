#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
need_cluster
echo "=== Setting up Scenario 10: MetalLB ==="
if ! kubectl get ns metallb-system >/dev/null 2>&1; then
  log "Installing MetalLB $METALLB_VERSION"
  kubectl apply -f "https://raw.githubusercontent.com/metallb/metallb/${METALLB_VERSION}/config/manifests/metallb-native.yaml" >/dev/null
fi
kubectl -n metallb-system rollout status deploy/controller --timeout=240s >/dev/null
kubectl -n metallb-system rollout status ds/speaker --timeout=240s >/dev/null
# the webhook needs a few seconds after the controller is up
retry 20 3 kubectl -n metallb-system get endpointslices -l kubernetes.io/service-name=metallb-webhook-service -o jsonpath="{.items[0].endpoints[0].addresses[0]}" >/dev/null || true

kubectl delete ns lb-lab --ignore-not-found --wait=true >/dev/null 2>&1 || true
kubectl create ns lb-lab >/dev/null
kubectl -n lb-lab apply -f - >/dev/null <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata: {name: shop-web}
spec:
  replicas: 2
  selector: {matchLabels: {app: shop-web}}
  template:
    metadata: {labels: {app: shop-web}}
    spec:
      containers:
      - {name: nginx, image: "nginx:1.27", ports: [{containerPort: 80}]}
EOF
kubectl -n lb-lab rollout status deploy/shop-web --timeout=120s >/dev/null
kubectl -n metallb-system delete ipaddresspools,l2advertisements --all >/dev/null 2>&1 || true
echo "=== Setup complete. See TASK.md ==="
