#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
check_header "Scenario 29: Istio ambient STRICT mTLS"

label_ok()  { eq "$(kubectl get ns bank -o jsonpath='{.metadata.labels.istio\.io/dataplane-mode}')" ambient; }
no_sidecar(){ ! kubectl -n bank get pods -o jsonpath='{.items[*].spec.containers[*].name}' | grep -q istio-proxy; }
pa_ok()     { eq "$(kubectl -n bank get peerauthentication default -o jsonpath='{.spec.mtls.mode}')" STRICT; }
pa_ns()     { [ -z "$(kubectl -n bank get peerauthentication default -o jsonpath='{.spec.selector}')" ]; }
in_mesh()   { istioctl ztunnel-config workloads 2>/dev/null | grep -E '^bank[[:space:]]+teller' | grep -qi HBONE; }
teller_ok() { retry 8 3 bash -c "[ \"\$(kubectl -n bank exec teller -- curl -s -m5 -o /dev/null -w '%{http_code}' http://ledger.bank 2>/dev/null)\" = 200 ]"; }
intr_blk()  { retry 5 3 bash -c "[ \"\$(kubectl -n outside exec intruder -- curl -s -m5 -o /dev/null -w '%{http_code}' http://ledger.bank 2>/dev/null)\" != 200 ]"; }

check "Namespace bank is labelled istio.io/dataplane-mode=ambient" label_ok
check "No sidecars were injected in bank" no_sidecar
check "teller is part of the mesh (HBONE in ztunnel-config)" in_mesh
check "PeerAuthentication default in bank has mTLS mode STRICT" pa_ok
check "It applies to the whole namespace (no workload selector)" pa_ns
check "teller (in mesh) still reaches ledger with HTTP 200" teller_ok
check "intruder (outside the mesh) is rejected" intr_blk
finish
