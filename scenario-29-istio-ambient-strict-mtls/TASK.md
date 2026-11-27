# Scenario 29 – Istio ambient: STRICT mTLS

**Domain 4 – Network Security and Policy** · Session: **Istio playground** (no Cilium BPF masquerade) · Time: ~12 min

## Context

Istio is installed with the **ambient** profile (ztunnel + istio-cni + istiod). Namespace
**`bank`** is **not** in the mesh yet. It contains Service `ledger` (port 80) and a client
Pod `teller` (ServiceAccount `teller`). Namespace **`outside`** is not in the mesh and
has a Pod `intruder`.

Today both clients can reach `ledger` in clear text:

```bash
kubectl -n bank    exec teller   -- curl -s -m5 http://ledger.bank       # ok
kubectl -n outside exec intruder -- curl -s -m5 http://ledger.bank       # ok (it should NOT be)
```

## Task

1. Put namespace **`bank`** into the **ambient mesh** (no Pod restart, no sidecars).
2. Make the workloads in `bank` **refuse plaintext** traffic: create a
   **`PeerAuthentication`** named **`default`** in `bank` with mTLS mode **`STRICT`**.
3. Verify: `teller` (in the mesh) still reaches `ledger`; `intruder` (outside the mesh)
   is **rejected** (connection reset or timeout).

## Test AFTER fix

```bash
kubectl get ns bank --show-labels
istioctl ztunnel-config workloads | grep bank
kubectl -n bank    exec teller   -- curl -s -m5 http://ledger.bank        # response
kubectl -n outside exec intruder -- curl -s -m5 http://ledger.bank        # curl: (56) / (28)
```

## Hints

- The namespace label is `istio.io/dataplane-mode=ambient`.
- `kubectl explain peerauthentication.spec.mtls`
- Docs: <https://istio.io/latest/docs/ambient/usage/add-workloads/> and
  <https://istio.io/latest/docs/reference/config/security/peer_authentication/>
