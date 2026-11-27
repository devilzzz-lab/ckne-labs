#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
need_cluster
echo "=== Setting up Scenario 20: Cluster Mesh repair ==="
mkdir -p /root/clustermesh "$ANS_DIR"
rm -f "$ANS_DIR/ca-copy.txt"
cat > /root/clustermesh/c1-values.yaml <<'EOF'
cluster:
  name: c1
  id: 1
ipam:
  mode: cluster-pool
  operator:
    clusterPoolIPv4PodCIDRList:
    - 10.1.0.0/16
clustermesh:
  useAPIServer: true
  apiserver:
    service:
      type: LoadBalancer
EOF
cat > /root/clustermesh/c2-values.yaml <<'EOF'
cluster:
  name: c1
  id: 1
ipam:
  mode: cluster-pool
  operator:
    clusterPoolIPv4PodCIDRList:
    - 10.1.0.0/16
clustermesh:
  useAPIServer: false
  apiserver:
    service:
      type: LoadBalancer
EOF
cat > /root/clustermesh/global-service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: shop
spec:
  selector:
    app: backend
  ports:
  - port: 80
    targetPort: 80
EOF
kubectl delete ns shop --ignore-not-found --wait=true >/dev/null 2>&1 || true
kubectl create ns shop >/dev/null
echo "Files written to /root/clustermesh/"
echo "=== Setup complete. See TASK.md ==="
