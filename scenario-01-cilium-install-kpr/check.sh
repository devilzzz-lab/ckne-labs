#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
check_header "Scenario 01: Install Cilium as a kube-proxy replacement"

agent_status() { kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg status 2>/dev/null; }
all_ready() { [ -z "$(kubectl get nodes --no-headers | awk '$2!="Ready"')" ] && [ "$(kubectl get nodes --no-headers | wc -l)" -ge 1 ]; }
cilium_ready() { eq "$(kubectl -n kube-system get ds cilium -o jsonpath='{.status.numberReady}')" "$(kubectl -n kube-system get ds cilium -o jsonpath='{.status.desiredNumberScheduled}')"; }
no_kubeproxy() { ! kubectl -n kube-system get ds kube-proxy; }
kpr_on() { agent_status | grep -E '^KubeProxyReplacement:' | grep -qi true; }
masq_bpf() { agent_status | grep -E '^Masquerading:' | grep -q BPF; }
host_set() { local h; h=$(kubectl -n kube-system get ds cilium -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="KUBERNETES_SERVICE_HOST")].value}'); eq "$h" "$(api_server_ip)"; }
excl_off() { eq "$(cilium_cfg cni-exclusive)" "false"; }

check "Cilium DaemonSet exists and is fully ready" cilium_ready
check "kube-proxy DaemonSet is gone" no_kubeproxy
check "KubeProxyReplacement is enabled" kpr_on
check "Masquerading mode is BPF" masq_bpf
check "Cilium uses the real API server address (k8sServiceHost)" host_set
check "cni.exclusive=false" excl_off
check "All nodes are Ready" all_ready
finish
