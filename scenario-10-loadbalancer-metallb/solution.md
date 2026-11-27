# Solution – Scenario 10: MetalLB

```bash
kubectl apply -f - <<'EOF'
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: lab-pool
  namespace: metallb-system
spec:
  addresses:
  - 172.30.255.200-172.30.255.220
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: lab-l2
  namespace: metallb-system
spec:
  ipAddressPools:
  - lab-pool
EOF

kubectl -n lb-lab expose deployment shop-web --name=shop-lb --type=LoadBalancer --port=80
kubectl -n lb-lab get svc shop-lb -w       # EXTERNAL-IP changes from <pending> to 172.30.255.200
```

## Why

- A `LoadBalancer` Service only gets an IP when something implements it. MetalLB's
  **controller** assigns IPs from `IPAddressPool` objects, and its **speaker** announces
  them. **L2Advertisement** = ARP/NDP from one node. A **BGPAdvertisement** would use BGP.
- With no pool, or a pool that no advertisement references, the Service stays pending (or
  gets an IP that nobody announces).
- Pin a Service to a pool with the annotation `metallb.io/address-pool: lab-pool`, or ask
  for a fixed IP with `spec.loadBalancerIP` / `metallb.io/loadBalancerIPs`.
- On Killercoda the two nodes are on different subnets, so L2 reachability from outside
  is not testable. The IP assignment is the part this lab checks.
- Cilium can do the same job natively (`CiliumLoadBalancerIPPool` + L2 announcements or BGP).
  Do not run two LB IPAM implementations for the same Services.
