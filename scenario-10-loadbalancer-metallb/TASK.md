# Scenario 10 – LoadBalancer Service with MetalLB

**Domain 2 – Service Networking and DNS** · Session: Any playground · Time: ~8 min

## Context

This cluster has no cloud provider, so a `LoadBalancer` Service stays `<pending>`.
MetalLB is installed (controller + speaker in `metallb-system`) but has **no address
pool yet**. Namespace `lb-lab` has Deployment `shop-web` (nginx, label `app=shop-web`,
port 80).

## Task

1. In `metallb-system`, create an **IPAddressPool** named **`lab-pool`** with the address
   range **`172.30.255.200-172.30.255.220`**.
2. Create an **L2Advertisement** named **`lab-l2`** that advertises `lab-pool`.
3. In `lb-lab`, expose `shop-web` with a Service named **`shop-lb`**, type
   **LoadBalancer**, port **80**.
4. The Service must receive an external IP **from `lab-pool`**.

## Test AFTER fix

```bash
kubectl -n metallb-system get ipaddresspools,l2advertisements
kubectl -n lb-lab get svc shop-lb
```

## Hints

- API: `metallb.io/v1beta1`. Both resources are namespaced in `metallb-system`.
- If the IP stays `<pending>`: `kubectl -n lb-lab describe svc shop-lb` and
  `kubectl -n metallb-system logs deploy/controller`.
- Docs: <https://metallb.io/configuration/> and <https://metallb.io/usage/>
