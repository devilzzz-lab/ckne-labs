#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
check_header "Scenario 20: Cluster Mesh repair"
F=/root/clustermesh/c2-values.yaml

name_ok()  { awk '/^cluster:/{f=1;next} /^[^ ]/{f=0} f&&/^[[:space:]]+name:/{print $2}' $F | grep -qx c2; }
id_ok()    { awk '/^cluster:/{f=1;next} /^[^ ]/{f=0} f&&/^[[:space:]]+id:/{print $2}' $F | grep -qx 2; }
cidr_ok()  { grep -Eq '^[[:space:]]*-[[:space:]]*10\.2\.0\.0/16[[:space:]]*$' $F && ! grep -q '10\.1\.0\.0/16' $F; }
api_ok()   { grep -Eq '^[[:space:]]+useAPIServer:[[:space:]]*true' $F; }
c1_same()  { grep -q 'name: c1' /root/clustermesh/c1-values.yaml && grep -q 'id: 1' /root/clustermesh/c1-values.yaml; }
svc_ann()  { eq "$(kubectl -n shop get svc backend -o jsonpath='{.metadata.annotations.service\.cilium\.io/global}')" true; }
svc_ok()   { eq "$(kubectl -n shop get svc backend -o jsonpath='{.spec.selector.app}')" backend && eq "$(kubectl -n shop get svc backend -o jsonpath='{.spec.ports[0].port}')" 80; }
ca_cmd()   { local c; c=$(cat "$ANS_DIR/ca-copy.txt" 2>/dev/null); echo "$c" | grep -q 'cilium-ca' && echo "$c" | grep -q 'kind-c1' && echo "$c" | grep -q 'kind-c2' && echo "$c" | grep -q 'kube-system' && echo "$c" | grep -Eq 'get secret|get secrets'; }

check "c2-values: cluster.name is c2" name_ok
check "c2-values: cluster.id is 2" id_ok
check "c2-values: pod CIDR is 10.2.0.0/16 (no overlap with c1)" cidr_ok
check "c2-values: clustermesh.useAPIServer is true" api_ok
check "c1-values.yaml was left untouched" c1_same
check "Service backend in ns shop is annotated service.cilium.io/global=true" svc_ann
check "Service backend keeps selector app=backend and port 80" svc_ok
check "ca-copy.txt copies Secret cilium-ca (kube-system) from kind-c1 to kind-c2" ca_cmd
finish
