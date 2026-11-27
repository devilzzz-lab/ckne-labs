# Solution – Scenario 08: Service types

```bash
kubectl -n svc-lab apply -f - <<'EOF'
apiVersion: v1
kind: Service
metadata: {name: web-clusterip}
spec:
  type: ClusterIP
  selector: {app: web}
  ports: [{port: 8080, targetPort: 80}]
---
apiVersion: v1
kind: Service
metadata: {name: web-nodeport}
spec:
  type: NodePort
  selector: {app: web}
  ports: [{port: 80, targetPort: 80, nodePort: 30088}]
---
apiVersion: v1
kind: Service
metadata: {name: web-headless}
spec:
  clusterIP: None
  selector: {app: web}
  ports: [{port: 80, targetPort: 80}]
---
apiVersion: v1
kind: Service
metadata: {name: docs}
spec:
  type: ExternalName
  externalName: kubernetes.io
EOF
```

Imperative shortcuts:

```bash
kubectl -n svc-lab expose deploy web --name=web-clusterip --port=8080 --target-port=80
kubectl -n svc-lab expose deploy web --name=web-nodeport --type=NodePort --port=80 --dry-run=client -o yaml   # add nodePort: 30088
kubectl -n svc-lab create service externalname docs --external-name kubernetes.io
```

## Why

| Type | What it does |
|------|--------------|
| ClusterIP | Virtual IP, reachable only inside the cluster |
| NodePort | ClusterIP **plus** a port (30000-32767) opened on every node |
| Headless | No virtual IP. DNS returns one A record per ready Pod |
| ExternalName | A DNS CNAME. No proxying, no endpoints, no port mapping |

`kubectl -n svc-lab get endpointslices` shows the backends behind each selector-based Service.
