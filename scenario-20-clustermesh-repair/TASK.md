# Scenario 20 – Cluster Mesh: repair the configuration

**Domain 3 – Advanced Traffic Management** · Session: Any playground · Time: ~12 min

## Context

A Killercoda playground has a single cluster, so you cannot build a real two-cluster
mesh here. Instead you repair the **configuration** of a mesh that does not come up. The
exam asks for exactly these kinds of facts. Two Helm value files and a Service manifest
are in **`/root/clustermesh/`**:

| File | Purpose |
|------|---------|
| `c1-values.yaml` | Cilium values for cluster **c1** (correct, use it as the reference) |
| `c2-values.yaml` | Cilium values for cluster **c2** (**broken**) |
| `global-service.yaml` | Service `backend` in namespace `shop`; it must be a **global service** |

The symptoms from the engineers: *"identities collide"*, *"remote nodes are 0"*, and
*"the client in c1 only ever reaches c1 backends"*.

## Task

1. **Fix `c2-values.yaml`** so the two clusters can be meshed: unique cluster name and
   id (c2 must use name **`c2`** and id **`2`**), a pod CIDR that does **not overlap** c1
   (**`10.2.0.0/16`**, and `10.1.0.0/16` must not appear anywhere in the file), and the
   clustermesh-apiserver enabled (`clustermesh.useAPIServer: true`). Leave `c1-values.yaml` as it is.
2. **Fix `global-service.yaml`** so that Cilium treats `backend` as a **global service**,
   then **apply** it to this cluster (`kubectl apply -f`).
3. Write the **one command** that copies the Cilium CA from cluster c1 to cluster c2
   (Secret `cilium-ca` in `kube-system`; contexts are `kind-c1` and `kind-c2`) into
   `/opt/answers/ca-copy.txt`. It must read the Secret from `kind-c1` (`kubectl ... get secret ...`)
   and create it in `kind-c2`.

## Test AFTER fix

```bash
cat /root/clustermesh/c2-values.yaml
kubectl -n shop get svc backend -o yaml | grep -A3 annotations
cat /opt/answers/ca-copy.txt
```

## Hints

- Mesh requirements: unique `cluster.name`, unique `cluster.id` (1-255), non-overlapping
  pod CIDRs, reachable nodes and apiserver, **shared CA**.
- Global service: same name + namespace in every cluster, annotation
  `service.cilium.io/global: "true"`.
- Docs: <https://docs.cilium.io/en/stable/network/clustermesh/clustermesh/> and
  <https://docs.cilium.io/en/stable/network/clustermesh/services/>
