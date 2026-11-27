# Scenario 19 – Cilium Egress Gateway

**Domain 3 – Advanced Traffic Management** · Session: **B (Cilium)** · Time: ~12 min

## Context

Pods labelled `app=billing` in namespace `payments` call a partner API in
`203.0.113.0/24`. The partner only accepts traffic from **one fixed source IP**. By
default a Pod's external traffic leaves from whichever node it runs on, with that node's
IP as the source.

The egress gateway node is **`node01`**. Its InternalIP is the fixed source IP
(`kubectl get node node01 -o wide`).

The Cilium baseline already has `kubeProxyReplacement=true` and `bpf.masquerade=true`.

## Task

1. Enable the Cilium **egress gateway** feature (`egressGateway.enabled=true`) and
   restart the Cilium agents **and** operator.
2. Label node `node01` with **`egress-gw=true`**.
3. Create a **`CiliumEgressGatewayPolicy`** named **`billing-egress`**:
   - selects Pods with `app=billing` in namespace `payments`
   - destination CIDR **`203.0.113.0/24`**
   - gateway node selected by label `egress-gw=true`
   - **`egressIP`** = node01's InternalIP

## Test AFTER fix

```bash
kubectl get ciliumegressgatewaypolicy billing-egress -o yaml
kubectl -n kube-system exec ds/cilium -- cilium-dbg bpf egress list     # run it on the agent of the Pod's node
```

## Hints

- `kubectl explain ciliumegressgatewaypolicy.spec`
- Pod selector labels: `app: billing` and `io.kubernetes.pod.namespace: payments`.
- If `bpf egress list` is empty, the feature was enabled but the agents were not restarted.
- Docs: <https://docs.cilium.io/en/stable/network/egress-gateway/egress-gateway/>
