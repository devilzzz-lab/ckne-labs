# Scenario 07 – Multi-interface Pod with Multus

**Domain 1 – Core Infrastructure and CNI** · Session: A or B · Time: ~10 min

## Context

Multus CNI is installed in `kube-system` (`setup.sh` did that). The primary CNI still
gives every Pod `eth0`. Multus can add extra interfaces described by
`NetworkAttachmentDefinition` (NAD) objects. The `bridge` and `host-local` CNI plugins
exist in `/opt/cni/bin` on both nodes.

## Task

In namespace `net`:

1. Create a NetworkAttachmentDefinition named **`internal-net`** that uses the CNI
   plugin **`bridge`** with a bridge named **`br-int`** and **`host-local`** IPAM for the
   subnet **`192.168.50.0/24`** (range `192.168.50.100` – `192.168.50.150`).
2. Create a Pod named **`dual-nic`** (image `busybox:1.36`, command `sleep 3600`) that
   attaches to `internal-net`.
3. The Pod must have **two interfaces**: `eth0` (primary) and **`net1`** with an address
   in `192.168.50.0/24`.

## Test AFTER fix

```bash
kubectl -n net get network-attachment-definitions
kubectl -n net exec dual-nic -- ip -br addr
kubectl -n net get pod dual-nic -o jsonpath='{.metadata.annotations.k8s\.v1\.cni\.cncf\.io/network-status}'
```

## Hints

- The Pod annotation is `k8s.v1.cni.cncf.io/networks: internal-net`.
- NAD `spec.config` is a JSON CNI config (`cniVersion`, `type`, `bridge`, `ipam`).
- If the Pod hangs in `ContainerCreating`, `kubectl describe pod` shows the CNI error.
- Quickstart: <https://github.com/k8snetworkplumbingwg/multus-cni/blob/master/docs/quickstart.md>
- Bridge plugin: <https://www.cni.dev/plugins/current/main/bridge/>
