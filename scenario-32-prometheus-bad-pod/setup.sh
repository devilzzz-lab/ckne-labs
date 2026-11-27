#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
need_cluster
echo "=== Setting up Scenario 32: Prometheus failing backend ==="
rm -f "$ANS_DIR"/bad-pod.txt "$ANS_DIR"/query.txt
BAD="orders-$((RANDOM % 4))"
state_set s32-bad "$BAD"
kubectl delete ns obs --ignore-not-found --wait=true >/dev/null 2>&1 || true
kubectl create ns obs >/dev/null
kubectl -n obs apply -f - >/dev/null <<EOF
apiVersion: v1
kind: ConfigMap
metadata: {name: orders-app}
data:
  app.py: |
    import os, random, socket, threading, time
    from http.server import BaseHTTPRequestHandler, HTTPServer
    bad = socket.gethostname() == os.environ.get("BAD_POD", "")
    counts = {"200": 0, "500": 0}
    def work():
        while True:
            time.sleep(0.2)
            if bad and random.random() < 0.6:
                counts["500"] += 1
            else:
                counts["200"] += 1
    threading.Thread(target=work, daemon=True).start()
    class H(BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path == "/metrics":
                body = "# TYPE app_http_requests_total counter\n"
                for c, v in counts.items():
                    body += 'app_http_requests_total{code="%s"} %d\n' % (c, v)
            else:
                body = "orders\n"
            self.send_response(200); self.end_headers(); self.wfile.write(body.encode())
        def log_message(self, *a): pass
    HTTPServer(("0.0.0.0", 8000), H).serve_forever()
---
apiVersion: v1
kind: Service
metadata: {name: orders}
spec:
  clusterIP: None
  selector: {app: orders}
  ports: [{port: 8000, targetPort: 8000}]
---
apiVersion: apps/v1
kind: StatefulSet
metadata: {name: orders}
spec:
  serviceName: orders
  replicas: 4
  selector: {matchLabels: {app: orders}}
  template:
    metadata:
      labels: {app: orders}
      annotations: {prometheus.io/scrape: "true", prometheus.io/port: "8000"}
    spec:
      containers:
      - name: app
        image: python:3.12-alpine
        command: ["python", "-u", "/app/app.py"]
        env: [{name: BAD_POD, value: "$BAD"}]
        ports: [{containerPort: 8000}]
        volumeMounts: [{name: code, mountPath: /app}]
      volumes: [{name: code, configMap: {name: orders-app}}]
---
apiVersion: v1
kind: ServiceAccount
metadata: {name: prometheus}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: {name: prometheus}
rules:
- apiGroups: [""]
  resources: ["pods", "services", "endpoints"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: {name: prometheus}
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: Role, name: prometheus}
subjects: [{kind: ServiceAccount, name: prometheus, namespace: obs}]
---
apiVersion: v1
kind: ConfigMap
metadata: {name: prometheus-conf}
data:
  prometheus.yml: |
    global:
      scrape_interval: 5s
    scrape_configs:
    - job_name: orders
      kubernetes_sd_configs:
      - role: pod
        namespaces: {names: [obs]}
      relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: "true"
      - source_labels: [__meta_kubernetes_pod_ip, __meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: (.+);(.+)
        replacement: \$1:\$2
        target_label: __address__
      - source_labels: [__meta_kubernetes_pod_name]
        target_label: pod
      - source_labels: [__meta_kubernetes_namespace]
        target_label: namespace
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: prometheus}
spec:
  replicas: 1
  selector: {matchLabels: {app: prometheus}}
  template:
    metadata: {labels: {app: prometheus}}
    spec:
      serviceAccountName: prometheus
      containers:
      - name: prometheus
        image: prom/prometheus:v3.5.0
        args: ["--config.file=/etc/prometheus/prometheus.yml", "--storage.tsdb.retention.time=1h"]
        ports: [{containerPort: 9090}]
        volumeMounts: [{name: conf, mountPath: /etc/prometheus}]
      volumes: [{name: conf, configMap: {name: prometheus-conf}}]
---
apiVersion: v1
kind: Service
metadata: {name: prometheus}
spec:
  type: NodePort
  selector: {app: prometheus}
  ports: [{port: 9090, targetPort: 9090, nodePort: 30090}]
EOF
kubectl -n obs rollout status sts/orders --timeout=240s >/dev/null
kubectl -n obs rollout status deploy/prometheus --timeout=240s >/dev/null
echo "Prometheus UI: http://<node-ip>:30090  (or kubectl -n obs port-forward svc/prometheus 9090:9090)"
echo "=== Setup complete. Wait 1-2 minutes, then see TASK.md ==="
