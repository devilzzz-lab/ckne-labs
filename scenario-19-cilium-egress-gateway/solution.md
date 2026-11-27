# Solution – Scenario 19: Cilium Egress Gateway

## Step 1 – Enable the feature

```bash
cilium config view | grep -E 'bpf-masquerade|kube-proxy-replacement'     # both must be on
# keep the running version: `cilium upgrade` without --version moves to the CLI's default version
CV=$(kubectl -n kube-system get ds cilium -o jsonpath='{.spec.template.spec.containers[0].image}' | sed -E 's/.*:v?([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
cilium upgrade --version $CV --reuse-values --set egressGateway.enabled=true
kubectl -n kube-system rollout restart ds/cilium deploy/cilium-operator
kubectl -n kube-system rollout status ds/cilium
```

## Step 2 – Label the gateway node and create the policy

```bash
kubectl label node node01 egress-gw=true
N1IP=$(kubectl get node node01 -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')

kubectl apply -f - <<EOF
apiVersion: cilium.io/v2
kind: CiliumEgressGatewayPolicy
metadata:
  name: billing-egress
spec:
  selectors:
  - podSelector:
      matchLabels:
        app: billing
        io.kubernetes.pod.namespace: payments
  destinationCIDRs:
  - 203.0.113.0/24
  egressGateway:
    nodeSelector:
      matchLabels:
        egress-gw: "true"
    egressIP: $N1IP
EOF
```

## Step 3 – Verify

```bash
# on the agent that runs the billing-client Pod (it is on the controlplane node)
POD=$(kubectl -n kube-system get pod -l k8s-app=cilium --field-selector spec.nodeName=controlplane -o name)
kubectl -n kube-system exec $POD -c cilium-agent -- cilium-dbg bpf egress list
#   Source IP    Destination CIDR    Egress IP      Gateway IP
#   10.0.0.23    203.0.113.0/24      <node01 IP>    <node01 IP>
```

## Why

- By default a Pod's external traffic is masqueraded to **its own node's IP**. The egress
  gateway redirects matching traffic to a **gateway node** and SNATs it there to a fixed
  `egressIP` (an IP that is configured on that node's interface).
- Prerequisites: `kubeProxyReplacement=true`, `bpf.masquerade=true`, `egressGateway.enabled=true`,
  and a restart of the agents **and** the operator after changing them.
- `CiliumEgressGatewayPolicy` is cluster-scoped. Limit it to one namespace with the
  `io.kubernetes.pod.namespace` label (or `namespaceSelector`).
- Typical failures: empty `bpf egress list` (not restarted), gateway IP `0.0.0.0` (no node
  matches `nodeSelector`), traffic dropped (`egressIP` is not on the gateway node).
- Istio has its own egress gateway (see scenario 21 and the Domain 3 study note).
