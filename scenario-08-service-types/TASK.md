# Scenario 08 – ClusterIP, NodePort, Headless and ExternalName Services

**Domain 2 – Service Networking and DNS** · Session: A or B · Time: ~8 min

## Context

Namespace `svc-lab` has Deployment `web` (nginx, 2 replicas, Pod label `app=web`,
container port 80) and a test Pod `toolbox` (curl + nslookup).

## Task

Create these four Services in namespace `svc-lab`. Use exactly these names and values:

| Name | Type | Port mapping | Notes |
|------|------|--------------|-------|
| `web-clusterip` | ClusterIP | `8080` → `80` | selects `app=web` |
| `web-nodeport` | NodePort | `80` → `80`, **nodePort `30088`** | selects `app=web` |
| `web-headless` | Headless | `80` → `80` | selects `app=web`, **no ClusterIP** |
| `docs` | ExternalName | n/a | points at `kubernetes.io` |

## Test AFTER fix

```bash
kubectl -n svc-lab get svc
kubectl -n svc-lab exec toolbox -- curl -s -m3 http://web-clusterip:8080 | head -3
kubectl -n svc-lab exec toolbox -- nslookup web-headless          # 2 Pod IPs
curl -s -m3 http://$(kubectl get node node01 -o jsonpath='{.status.addresses[0].address}'):30088 | head -3
kubectl -n svc-lab exec toolbox -- nslookup docs
```

## Hints

- `kubectl expose deployment web --help`, and `--dry-run=client -o yaml` to edit.
- Headless = `clusterIP: None`. DNS then returns the Pod IPs directly.
- `kubectl create service externalname --help`
- Docs: <https://kubernetes.io/docs/concepts/services-networking/service/>
