# Solution – Scenario 34: Envoy access logs

## Step 1 – Read the logs

```bash
SEL='gateway.envoyproxy.io/owning-gateway-name=web-gw'
kubectl -n envoy-gateway-system get pods -l $SEL
kubectl -n envoy-gateway-system logs -l $SEL -c envoy --tail=-1 | head -3
```

If the lines are JSON, `jq` is the clean way. If they are plain text, `grep` and `awk` do it.

## Step 2 – User agents with failing /api/login requests (JSON logs)

```bash
LOGS=$(kubectl -n envoy-gateway-system logs -l $SEL -c envoy --tail=-1)

echo "$LOGS" | jq -R -r 'fromjson?
   | select((."x-envoy-origin-path" // "") | startswith("/api/login"))
   | select((.response_code | tonumber) >= 400)
   | ."user-agent"' | sort | uniq -c | sort -rn
#   180 BruteBot/417          <- the answer: by far the most failures
#    20 curl/8.5.0          <- a second, much slower client: not the one

echo "$LOGS" | jq -R -r 'fromjson?
   | select((."x-envoy-origin-path" // "") | startswith("/api/login"))
   | select((.response_code | tonumber) >= 400)
   | .downstream_remote_address' | sed 's/:[0-9]*$//' | sort | uniq -c | sort -rn
```

Without `jq`:

```bash
echo "$LOGS" | grep '/api/login' | grep -E '"response_code":"?4' | grep -o '"user-agent":"[^"]*"' | sort | uniq -c | sort -rn
```

```bash
echo 'BruteBot/417' > /opt/answers/agent.txt        # the string YOU found
echo '10.0.1.23'    > /opt/answers/client-ip.txt    # the Pod IP YOU found
```

Cross-check the IP with a Pod: `kubectl -n web get pods -o wide`.

## Why

- `x-envoy-origin-path` is the **original** request path. `response_code` is the status.
  `response_flags` explains **why** Envoy failed a request:

  | Flag | Meaning |
  |------|---------|
  | `UH` | no healthy upstream (503) |
  | `UF` | upstream connection failure (503) |
  | `UT` | upstream timeout (504) |
  | `NR` | no route matched (404) |
  | `URX` | retry limit reached |
  | `RL` | rate limited (429) |
  | `DC` | downstream client closed the connection |

- Three decoys sit in this data: a client with **200s** on `/api/login`, a client with
  **403s on another path**, and a **slow** client with 401s. Filter on **both** path and
  status before you count.
- If the client came through a load balancer, the real address is in `x-forwarded-for`, not
  `downstream_remote_address`.
- For routing problems check the Gateway **controller** logs
  (`kubectl -n envoy-gateway-system logs deploy/envoy-gateway`). For data-plane behaviour use
  the proxy logs above. For policy denials use `hubble observe` / ztunnel / waypoint logs.
