# Solution – Scenario 09: Service without selector + EndpointSlice

```bash
N1IP=$(kubectl get node node01 -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')

kubectl -n ext apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: external-api
spec:
  ports:
  - name: http
    port: 80
    targetPort: 8088
---
apiVersion: discovery.k8s.io/v1
kind: EndpointSlice
metadata:
  name: external-api-1
  labels:
    kubernetes.io/service-name: external-api
addressType: IPv4
ports:
- name: http
  protocol: TCP
  port: 8088
endpoints:
- addresses:
  - $N1IP
EOF

kubectl -n ext exec toolbox -- curl -s -m3 http://external-api       # external-api-ok
```

## Why

Three details make this work. All of them are common reasons it silently fails:

1. The Service has **no `selector`**, so the control plane does not manage its endpoints.
2. The EndpointSlice has the **`kubernetes.io/service-name`** label. That is the link
   between the slice and the Service.
3. Port **names** match (`http`), and the slice port is the **real server port** (8088).

If the backend were a DNS name instead of an IP, use `type: ExternalName` instead.
Kubernetes rejects loopback and link-local addresses in endpoints.
