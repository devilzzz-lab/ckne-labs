#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
need_cluster
echo "=== Setting up Scenario 33: Jaeger slow hop ==="
rm -f "$ANS_DIR"/slow-service.txt "$ANS_DIR"/error-service.txt
svcs=(cart pricing inventory)
SLOW=${svcs[$((RANDOM % 3))]}
ERR=$SLOW; while [ "$ERR" = "$SLOW" ]; do ERR=${svcs[$((RANDOM % 3))]}; done
state_set s33-slow "$SLOW"; state_set s33-err "$ERR"

kubectl delete ns tracing --ignore-not-found --wait=true >/dev/null 2>&1 || true
kubectl create ns tracing >/dev/null
kubectl -n tracing apply -f - >/dev/null <<EOF
apiVersion: apps/v1
kind: Deployment
metadata: {name: jaeger}
spec:
  replicas: 1
  selector: {matchLabels: {app: jaeger}}
  template:
    metadata: {labels: {app: jaeger}}
    spec:
      containers:
      - name: jaeger
        image: jaegertracing/jaeger:${JAEGER_VERSION}
        ports:
        - {containerPort: 16686}
        - {containerPort: 4317}
        - {containerPort: 4318}
---
apiVersion: v1
kind: Service
metadata: {name: jaeger}
spec:
  type: NodePort
  selector: {app: jaeger}
  ports:
  - {name: ui, port: 16686, targetPort: 16686, nodePort: 30686}
  - {name: otlp-grpc, port: 4317, targetPort: 4317}
  - {name: otlp-http, port: 4318, targetPort: 4318}
---
apiVersion: v1
kind: ConfigMap
metadata: {name: tracegen}
data:
  gen.py: |
    import json, os, random, time, urllib.request
    URL = "http://jaeger:4318/v1/traces"
    SLOW, ERR = os.environ["SLOW"], os.environ["ERR"]
    CHAIN = ["frontend", "cart", "pricing", "inventory"]
    def hexid(n): return "%0*x" % (n, random.getrandbits(n * 4))
    def span(svc, trace, parent, start, dur, error=False):
        sid = hexid(16)
        attrs = [{"key": "http.method", "value": {"stringValue": "GET"}},
                 {"key": "http.status_code", "value": {"intValue": "503" if error else "200"}}]
        if error:
            attrs.append({"key": "error", "value": {"boolValue": True}})
        s = {"traceId": trace, "spanId": sid, "name": "GET /" + svc, "kind": 2,
             "startTimeUnixNano": str(start), "endTimeUnixNano": str(start + dur),
             "attributes": attrs}
        if parent: s["parentSpanId"] = parent
        if error: s["status"] = {"code": 2, "message": "upstream 503"}
        return {"resource": {"attributes": [{"key": "service.name", "value": {"stringValue": svc}}]},
                "scopeSpans": [{"scope": {"name": "tracegen"}, "spans": [s]}]}, sid
    def one_trace():
        trace = hexid(32); now = time.time_ns(); ms = 1_000_000
        own = {s: random.randint(8, 25) * ms for s in CHAIN}
        own[SLOW] += random.randint(650, 900) * ms
        err_here = (random.random() < 0.25)
        total = sum(own.values())
        out = []; parent = None; start = now; remaining = total
        for s in CHAIN:
            rs, sid = span(s, trace, parent, start, remaining, error=(err_here and s == ERR))
            out.append(rs); parent = sid; start += own[s]; remaining -= own[s]
        body = json.dumps({"resourceSpans": out}).encode()
        req = urllib.request.Request(URL, data=body, headers={"Content-Type": "application/json"})
        urllib.request.urlopen(req, timeout=5).read()
    while True:
        try: one_trace()
        except Exception as e: print("retry:", e, flush=True)
        time.sleep(1)
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: tracegen}
spec:
  replicas: 1
  selector: {matchLabels: {app: tracegen}}
  template:
    metadata: {labels: {app: tracegen}}
    spec:
      containers:
      - name: gen
        image: python:3.12-alpine
        command: ["python", "-u", "/gen/gen.py"]
        env: [{name: SLOW, value: "$SLOW"}, {name: ERR, value: "$ERR"}]
        volumeMounts: [{name: code, mountPath: /gen}]
      volumes: [{name: code, configMap: {name: tracegen}}]
EOF
kubectl -n tracing rollout status deploy/jaeger --timeout=240s >/dev/null
kubectl -n tracing rollout status deploy/tracegen --timeout=240s >/dev/null
echo "Jaeger UI: http://<node-ip>:30686  (or kubectl -n tracing port-forward svc/jaeger 16686:16686)"
echo "=== Setup complete. Wait about a minute, then see TASK.md ==="
