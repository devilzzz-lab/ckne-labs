#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
check_header "Scenario 02: IPAM and Pod CIDR investigation"

mode=$(cilium_cfg ipam)
ccidr=$(grep -h -- '--cluster-cidr' /etc/kubernetes/manifests/kube-controller-manager.yaml 2>/dev/null | head -1 | sed 's/.*--cluster-cidr=//;s/[[:space:]]*$//')
pcidr=$(kubectl get ciliumnode node01 -o jsonpath='{.spec.ipam.podCIDRs[0]}' 2>/dev/null)
if [ "$mode" = kubernetes ]; then src=node; else src=operator; fi

check "ipam-mode.txt = $mode" eq "$(ans ipam-mode.txt)" "$mode"
if [ -n "$ccidr" ]; then
  check "cluster-cidr.txt = $ccidr" eq "$(ans cluster-cidr.txt)" "$ccidr"
else
  check "cluster-cidr.txt is a CIDR (controller-manager flag not readable here)" bash -c "grep -Eq '^[0-9.]+/[0-9]+$' $ANS_DIR/cluster-cidr.txt"
fi
check "node01-podcidr.txt = $pcidr" eq "$(ans node01-podcidr.txt)" "$pcidr"
check "node01-cidr-source.txt = $src" eq "$(ans node01-cidr-source.txt)" "$src"
finish
