# Scenario 24 – Cilium FQDN egress policy

**Domain 4 – Network Security and Policy** · Session: **B (Cilium)** · Time: ~10 min

## Context

The Pod `client` (label `app=client`) in namespace `fqdn` currently reaches the whole
internet. Policy: it may only call **`example.com`** over HTTPS, and it still needs DNS.

```bash
kubectl -n fqdn exec client -- curl -s -o /dev/null -w '%{http_code}\n' -m6 https://example.com      # 200 today
kubectl -n fqdn exec client -- curl -s -o /dev/null -w '%{http_code}\n' -m6 https://www.wikipedia.org # 200 today
```

## Task

Create a **`CiliumNetworkPolicy`** named **`client-egress`** in `fqdn` for Pods
`app=client`:

1. Egress to **`kube-dns`** (Pods in `kube-system` with `k8s-app=kube-dns`) on port **53**
   (any protocol) with a **DNS rule** that lets the Cilium DNS proxy observe all lookups
   (`matchPattern: "*"`).
2. Egress to the FQDN **`example.com`** on **TCP 443** (`toFQDNs`).
3. Everything else is denied.

Result: `https://example.com` → **200**, `https://www.wikipedia.org` → **blocked**
(timeout / connection failure).

## Test AFTER fix

```bash
kubectl -n fqdn exec client -- curl -s -o /dev/null -w '%{http_code}\n' -m6 https://example.com
kubectl -n fqdn exec client -- curl -s -o /dev/null -w '%{http_code}\n' -m6 https://www.wikipedia.org     # 000
hubble observe -n fqdn --verdict DROPPED       # (if Hubble is enabled)
```

## Hints

- `toFQDNs` only works if the DNS lookup goes through Cilium's DNS proxy, which needs the
  **DNS rule** from step 1. Without it the IPs are never learned.
- `kubectl explain ciliumnetworkpolicy.spec.egress`
- Docs: <https://docs.cilium.io/en/stable/security/policy/language/#dns-based>
