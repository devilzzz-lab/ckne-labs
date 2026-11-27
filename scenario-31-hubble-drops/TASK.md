# Scenario 31 – Hubble: find the dropped workload

**Domain 5 – Observability** · Session: **B (Cilium)** · Time: ~10 min

## Context

In namespace `finance`, three client Deployments (`app-a`, `app-b`, `app-c`) call the
database Service `db` (port **5432**) every two seconds. A CiliumNetworkPolicy
`db-ingress` protects `db`. The dashboard shows that **one** client never gets an answer.
Hubble is enabled (`setup.sh` enabled it and installed the `hubble` CLI).

## Task

1. Use **Hubble** (CLI or UI) to find the client whose traffic to `db` is **dropped**.
   Write its **Pod label `app` value** (for example `app-b`) into
   `/opt/answers/dropped-source.txt`.
2. Write the **drop reason** that Hubble reports into `/opt/answers/drop-reason.txt`.
3. **Fix it** with the smallest change: let that client reach `db:5432`. The two clients
   that already work must keep working, and `db` must still **not** be open to everybody
   (no allow-all).

## Test AFTER fix

```bash
hubble observe -n finance --verdict DROPPED --last 20
kubectl -n finance exec deploy/app-a -- curl -s -m3 http://db:5432
```

## Hints

- Start the Hubble relay port-forward: `cilium hubble port-forward &`, then `hubble status`.
  Or use the agent's built-in client: `kubectl -n kube-system exec ds/cilium -- hubble observe ...`.
- `hubble observe -n finance --to-label app=db --verdict DROPPED`
- `cilium hubble ui` opens the service map (port-forward it with `kubectl -n kube-system port-forward svc/hubble-ui 12000:80`).
- Docs: <https://docs.cilium.io/en/stable/observability/hubble/>
