# Solution – Scenario 20: Cluster Mesh repair

## Step 1 – `/root/clustermesh/c2-values.yaml`

```yaml
cluster:
  name: c2                  # was c1  -> identity / name collision
  id: 2                     # was 1   -> duplicate cluster ID
ipam:
  mode: cluster-pool
  operator:
    clusterPoolIPv4PodCIDRList:
    - 10.2.0.0/16           # was 10.1.0.0/16 -> overlapping pod CIDRs, no routing between clusters
clustermesh:
  useAPIServer: true        # was false -> no clustermesh-apiserver, "0 remote nodes"
  apiserver:
    service:
      type: LoadBalancer
```

## Step 2 – the global service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: shop
  annotations:
    service.cilium.io/global: "true"        # the missing line
spec:
  selector:
    app: backend
  ports:
  - port: 80
    targetPort: 80
```

```bash
kubectl apply -f /root/clustermesh/global-service.yaml
kubectl -n shop get svc backend -o jsonpath='{.metadata.annotations}'
```

## Step 3 – the CA command

```bash
cat > /opt/answers/ca-copy.txt <<'EOF'
kubectl --context kind-c1 -n kube-system get secret cilium-ca -o yaml | kubectl --context kind-c2 create -f -
EOF
```

## The real setup this models (two clusters)

```bash
cilium install --context kind-c1 --set cluster.name=c1 --set cluster.id=1 \
  --set ipam.operator.clusterPoolIPv4PodCIDRList=10.1.0.0/16
kubectl --context kind-c1 -n kube-system get secret cilium-ca -o yaml | kubectl --context kind-c2 create -f -
cilium install --context kind-c2 --set cluster.name=c2 --set cluster.id=2 \
  --set ipam.operator.clusterPoolIPv4PodCIDRList=10.2.0.0/16
cilium clustermesh enable --context kind-c1 --service-type LoadBalancer
cilium clustermesh enable --context kind-c2 --service-type LoadBalancer
cilium clustermesh status --context kind-c1 --wait
cilium clustermesh connect --context kind-c1 --destination-context kind-c2
```

## Why (cheat table)

| Symptom | Likely cause |
|---------|--------------|
| 0 remote nodes | clustermesh-apiserver unreachable (no LB IP, firewall) or not enabled |
| TLS / certificate errors | the clusters do not share a CA (`cilium-ca` not copied before the 2nd install) |
| duplicate cluster id | same `cluster.id` in two clusters |
| global service only hits local backends | annotation missing in **one** cluster, or `affinity: local` with healthy local backends |
| cross-cluster Pod traffic dropped | pod CIDRs overlap, or a policy does not allow the remote identity |
