#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
need_cluster
echo "=== Setting up Scenario 18: Cilium BGP Control Plane ==="
require_cilium
kubectl delete ciliumbgpclusterconfigs,ciliumbgppeerconfigs,ciliumbgpadvertisements --all >/dev/null 2>&1 || true
kubectl label node controlplane bgp- >/dev/null 2>&1 || true
kubectl delete ns bgp-lab --ignore-not-found --wait=true >/dev/null 2>&1 || true
kubectl create ns bgp-lab >/dev/null
kubectl -n bgp-lab apply -f - >/dev/null <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata: {name: frr-conf}
data:
  daemons: |
    bgpd=yes
    ospfd=no
    ospf6d=no
    ripd=no
    ripngd=no
    isisd=no
    pimd=no
    ldpd=no
    nhrpd=no
    eigrpd=no
    babeld=no
    sharpd=no
    pbrd=no
    bfdd=no
    fabricd=no
    vtysh_enable=yes
    zebra_options="  -A 127.0.0.1 -s 90000000"
    bgpd_options="   -A 127.0.0.1"
  vtysh.conf: |
    service integrated-vtysh-config
  frr.conf: |
    frr defaults traditional
    hostname frr-router
    log stdout informational
    router bgp 65000
     bgp router-id 10.255.0.1
     no bgp ebgp-requires-policy
     no bgp network import-check
     neighbor CILIUM peer-group
     neighbor CILIUM remote-as 65001
     bgp listen range 10.0.0.0/8 peer-group CILIUM
     bgp listen range 172.16.0.0/12 peer-group CILIUM
     bgp listen range 192.168.0.0/16 peer-group CILIUM
     address-family ipv4 unicast
      neighbor CILIUM activate
      neighbor CILIUM soft-reconfiguration inbound
     exit-address-family
    line vty
---
apiVersion: v1
kind: Pod
metadata: {name: frr-router, labels: {app: frr-router}}
spec:
  containers:
  - name: frr
    image: quay.io/frrouting/frr:10.4.5
    securityContext: {privileged: true}
    command: ["/bin/sh", "-c", "cp /conf/* /etc/frr/ && chown frr:frr /etc/frr/*; exec /sbin/tini -- /usr/lib/frr/docker-start"]
    volumeMounts: [{name: conf, mountPath: /conf}]
  volumes: [{name: conf, configMap: {name: frr-conf}}]
EOF
wait_ready bgp-lab pod/frr-router 240s || warn "frr-router is not Ready. The task checks only your Cilium resources, but 'cilium bgp peers' will not establish."
echo "frr-router Pod IP (peerAddress): $(kubectl -n bgp-lab get pod frr-router -o jsonpath='{.status.podIP}')"
echo "=== Setup complete. See TASK.md ==="
