# Solution – Scenario 31: Hubble drops

## Step 1 – Find the dropped flows

```bash
cilium hubble port-forward &                 # Hubble Relay on localhost:4245
hubble status

hubble observe -n finance --to-label app=db --verdict DROPPED --last 20
#   finance/app-c-xxxx:41234 (ID:1234) <> finance/db-yyyy:5432 (ID:5678) Policy denied DROPPED (TCP Flags: SYN)
```

The source Pod name (`app-c-...`) and its label tell you the client. Count them if the
output is long:

```bash
hubble observe -n finance --verdict DROPPED -o json \
  | jq -r '.flow.source.labels[] | select(startswith("k8s:app="))' | sort | uniq -c
hubble observe -n finance --verdict DROPPED -o json | jq -r '.flow.drop_reason_desc' | sort | uniq -c
#   POLICY_DENIED
```

```bash
echo app-c > /opt/answers/dropped-source.txt            # use the one YOU found
echo "Policy denied" > /opt/answers/drop-reason.txt
```

In the **Hubble UI** (`cilium hubble ui`): choose namespace `finance`. The service map shows a
red edge from the blocked client to `db`, and the flow table lists the `dropped` verdict.

## Step 2 – Smallest fix: add that client to the allow-list

```bash
kubectl -n finance get cnp db-ingress -o yaml        # allows two apps only
kubectl -n finance patch cnp db-ingress --type=json -p \
  '[{"op":"add","path":"/spec/ingress/0/fromEndpoints/-","value":{"matchLabels":{"app":"app-c"}}}]'
```

(Or create a second CiliumNetworkPolicy that adds one more `fromEndpoints` rule. Rules from
several policies are unioned.)

## Verify

```bash
hubble observe -n finance --to-label app=db --last 10          # FORWARDED
kubectl -n finance exec deploy/app-c -- curl -s http://db:5432   # db-ok
```

## Why

| Drop reason (Hubble text / JSON enum) | Typical cause |
|---------------------------------------|---------------|
| `Policy denied` / `POLICY_DENIED` | no policy allows this identity on this port |
| `Policy denied by denylist` / `POLICY_DENY` | explicit `ingressDeny` / `egressDeny` |
| `Stale or unroutable IP` | the endpoint is gone (Pod restarted) |
| `Service backend not found` | the Service has no ready endpoints |

Fix the **identity** (label) that is missing from the allow-list. Do not add `fromEntities:
all` just to make the drop go away.
