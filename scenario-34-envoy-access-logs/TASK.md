# Scenario 34 – Envoy access logs: who is hitting /api/login?

**Domain 5 – Observability** · Session: A or B · Time: ~10 min

## Context

Gateway **`web-gw`** (namespace `web`, Envoy Gateway) fronts Service `api`. Several clients
call it all the time. One of them is hammering **`/api/login`** and getting **4xx
responses**: a brute-force attempt. The Envoy access logs show every request.

Envoy proxy Pods run in `envoy-gateway-system`, labelled
`gateway.envoyproxy.io/owning-gateway-name=web-gw`. Access logs go to the **`envoy`**
container's stdout.

## Task

Find the client that sends the **most failing (status ≥ 400) requests to `/api/login`**
and write:

1. its **`User-Agent`** (exact string) to `/opt/answers/agent.txt`
2. its **source IP address** (IP only, no port) to `/opt/answers/client-ip.txt`

## Test AFTER fix

```bash
cat /opt/answers/agent.txt /opt/answers/client-ip.txt
```

## Hints

```bash
kubectl -n envoy-gateway-system get pods -l gateway.envoyproxy.io/owning-gateway-name=web-gw
kubectl -n envoy-gateway-system logs -l gateway.envoyproxy.io/owning-gateway-name=web-gw -c envoy --tail=-1 | head -3
```

- Fields to look for: `x-envoy-origin-path`, `response_code`, `user-agent`,
  `x-forwarded-for`, `downstream_remote_address`.
- Filter with `grep '/api/login'`, or with `jq -R 'fromjson? | select(...)'` if logs are JSON.
- Not every client that calls `/api/login` fails, and not every failing client uses
  `/api/login`. Count carefully (`sort | uniq -c | sort -rn`).
- Docs: <https://gateway.envoyproxy.io/docs/tasks/observability/proxy-accesslog/>
