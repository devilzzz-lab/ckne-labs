# Solution – Scenario 22: NetworkPolicy default deny

```bash
kubectl -n lockdown apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: default-deny}
spec:
  podSelector: {}
  policyTypes: ["Ingress", "Egress"]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: allow-dns}
spec:
  podSelector: {}
  policyTypes: ["Egress"]
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - {protocol: UDP, port: 53}
    - {protocol: TCP, port: 53}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: api-ingress}
spec:
  podSelector:
    matchLabels: {app: api}
  policyTypes: ["Ingress"]
  ingress:
  - from:
    - podSelector:
        matchLabels: {app: frontend}
    ports:
    - {protocol: TCP, port: 8080}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: frontend-egress}
spec:
  podSelector:
    matchLabels: {app: frontend}
  policyTypes: ["Egress"]
  egress:
  - to:
    - podSelector:
        matchLabels: {app: api}
    ports:
    - {protocol: TCP, port: 8080}
EOF
```

## Why

- A Pod is open until **some policy selects it** for a direction. After that only traffic
  that a policy allows gets through. Policies **add up** (union).
- Default-deny **egress** also blocks DNS (it is egress to `kube-dns`). Always pair it
  with an allow-DNS rule, or every lookup times out.
- A connection needs **both** sides allowed when both are selected: egress on the
  client Pod **and** ingress on the server Pod.
- `from: [ {namespaceSelector}, {podSelector} ]` (two list items) is **OR**.
  `from: [ {namespaceSelector, podSelector} ]` (one item) is **AND**. This difference is a
  classic exam trap.
- Service ClusterIPs are translated **before** policy is evaluated, so write the rule
  against the **Pods** (`podSelector`), never against the Service IP.
