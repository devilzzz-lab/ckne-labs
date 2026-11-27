#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
need_cluster
echo "=== Setting up Scenario 12: CoreDNS forward a corporate domain ==="
coredns_backup
coredns_restore >/dev/null 2>&1 || true   # start from the pristine Corefile
kubectl -n kube-system rollout status deploy/coredns --timeout=120s >/dev/null

kubectl delete ns dns-lab --ignore-not-found --wait=true >/dev/null 2>&1 || true
kubectl create ns dns-lab >/dev/null
kubectl -n dns-lab apply -f - >/dev/null <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata: {name: corp-dns-conf}
data:
  Corefile: |
    .:53 {
        hosts {
            10.20.30.40 app.corp.internal
            10.20.30.41 db.corp.internal
        }
        errors
        log
    }
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: corp-dns}
spec:
  replicas: 1
  selector: {matchLabels: {app: corp-dns}}
  template:
    metadata: {labels: {app: corp-dns}}
    spec:
      containers:
      - name: coredns
        image: coredns/coredns:1.12.0
        args: ["-conf", "/etc/coredns/Corefile"]
        ports:
        - {containerPort: 53, protocol: UDP}
        - {containerPort: 53, protocol: TCP}
        volumeMounts: [{name: conf, mountPath: /etc/coredns}]
      volumes: [{name: conf, configMap: {name: corp-dns-conf}}]
---
apiVersion: v1
kind: Service
metadata: {name: corp-dns}
spec:
  selector: {app: corp-dns}
  ports:
  - {name: udp, port: 53, protocol: UDP}
  - {name: tcp, port: 53, protocol: TCP}
EOF
ensure_toolbox dns-lab
kubectl -n dns-lab rollout status deploy/corp-dns --timeout=120s >/dev/null
wait_ready dns-lab pod/toolbox
echo "corp-dns ClusterIP: $(kubectl -n dns-lab get svc corp-dns -o jsonpath='{.spec.clusterIP}')"
echo "=== Setup complete. See TASK.md ==="
