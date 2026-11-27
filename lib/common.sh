#!/usr/bin/env bash
# Shared helpers for the CKNE labs. SOURCE this file, do not execute it.
# Assumes: Killercoda 2-node kubeadm playground, you are root on "controlplane",
# and `ssh node01` works.

LAB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${CKNE_STATE_DIR:-/var/lib/ckne-labs}"
ANS_DIR="${CKNE_ANSWERS_DIR:-/opt/answers}"
mkdir -p "$STATE_DIR" "$ANS_DIR" 2>/dev/null || true

# ── Pinned versions (verified current on 2026-11-27) ─────────────────
CILIUM_VERSION="${CILIUM_VERSION:-1.20.5}"
CILIUM_CLI_VERSION="${CILIUM_CLI_VERSION:-v0.20.3}"
EG_VERSION="${EG_VERSION:-v1.10.0}"
METALLB_VERSION="${METALLB_VERSION:-v0.16.2}"
CERT_MANAGER_VERSION="${CERT_MANAGER_VERSION:-v1.21.3}"
ISTIO_VERSION="${ISTIO_VERSION:-1.32.0}"
GIE_VERSION="${GIE_VERSION:-v1.6.2}"            # Gateway API Inference Extension
MULTUS_VERSION="${MULTUS_VERSION:-v4.3.2}"
JAEGER_VERSION="${JAEGER_VERSION:-2.23.0}"

# ── Output helpers ───────────────────────────────────────────────────
log()  { printf '  \033[0;36m→\033[0m %s\n' "$*"; }
warn() { printf '  \033[1;33m!\033[0m %s\n' "$*"; }
die()  { printf '  \033[0;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

# ── Basics ───────────────────────────────────────────────────────────
# Run a command on node01 (the Killercoda worker).
n1() { ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=8 node01 "$@"; }
# Run the same shell snippet on controlplane and node01.
on_all_nodes() { bash -c "$1" || true; n1 "$1" || true; }

node_ip()       { kubectl get node "$1" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}'; }
api_server_ip() { kubectl get endpointslices -n default -l kubernetes.io/service-name=kubernetes -o jsonpath='{.items[0].endpoints[0].addresses[0]}'; }
retry()         { local n=$1 s=$2 i; shift 2; for ((i = 0; i < n; i++)); do "$@" && return 0; sleep "$s"; done; return 1; }

need_cluster() { kubectl get nodes --request-timeout=8s >/dev/null 2>&1 || die "kubectl cannot reach the cluster."; }

state_set() { echo "$2" > "$STATE_DIR/$1"; }
state_get() { cat "$STATE_DIR/$1" 2>/dev/null; }

# First line of an answer file, trimmed.
ans() { head -n1 "$ANS_DIR/$1" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'; }

# ── CNI detection ────────────────────────────────────────────────────
cni_kind() {
  if kubectl -n kube-system get ds cilium >/dev/null 2>&1; then echo cilium
  elif kubectl get ns calico-system >/dev/null 2>&1 || kubectl -n kube-system get ds calico-node >/dev/null 2>&1; then echo calico
  else echo other; fi
}
cilium_cfg() { kubectl -n kube-system get cm cilium-config -o jsonpath="{.data.$1}" 2>/dev/null; }

require_cilium() {
  [ "$(cni_kind)" = cilium ] || die "This scenario needs Cilium. Do scenario 01 first (or run ./cluster/install-cilium.sh)."
  kubectl -n kube-system rollout status ds/cilium --timeout=180s >/dev/null 2>&1 || die "Cilium DaemonSet is not ready yet."
  ensure_cilium_cli
}
# Version of the running Cilium agent (e.g. 1.20.5).
cilium_running_version() {
  kubectl -n kube-system get ds cilium -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null \
    | sed -E 's/.*:v?([0-9]+\.[0-9]+\.[0-9]+).*/\1/'
}
# Change Cilium Helm values WITHOUT changing the Cilium version, then restart so the agents read them.
# (`cilium upgrade` without --version moves to the CLI's default version.)
cilium_set() {
  ensure_cilium_cli
  local v; v=$(cilium_running_version)
  cilium upgrade --version "$v" --reuse-values "$@" || return 1
  kubectl -n kube-system rollout restart ds/cilium deploy/cilium-operator >/dev/null
  kubectl -n kube-system rollout status ds/cilium --timeout=300s >/dev/null
}
# Istio ambient on Cilium needs cni.exclusive=false (else Cilium removes the istio-cni config) and,
# with kube-proxy replacement, socketLB.hostNamespaceOnly=true. It does NOT work with bpf.masquerade=true.
# Docs: https://docs.cilium.io/en/stable/network/servicemesh/istio/
require_no_bpf_masq() {
  [ "$(cni_kind)" = cilium ] || return 0
  if [ "$(cilium_cfg enable-bpf-masquerade)" = "true" ]; then
    die "Istio ambient does not work with Cilium bpf.masquerade=true (you did lab 01 / install-cilium.sh). Restart the Killercoda playground for this scenario."
  fi
  local args=()
  [ "$(cilium_cfg cni-exclusive)" = false ] || args+=(--set cni.exclusive=false)
  if [ "$(cilium_cfg kube-proxy-replacement)" = true ] && [ "$(cilium_cfg bpf-lb-sock-hostns-only)" != true ]; then
    args+=(--set socketLB.hostNamespaceOnly=true)
  fi
  if [ ${#args[@]} -gt 0 ]; then
    log "Preparing Cilium for Istio ambient: ${args[*]}"
    cilium_set "${args[@]}" || die "Could not change Cilium settings. Run by hand: cilium upgrade --version $(cilium_running_version) --reuse-values ${args[*]}"
  fi
}

# ── Tool installers (idempotent) ─────────────────────────────────────
ensure_helm() {
  command -v helm >/dev/null && return 0
  log "Installing helm"
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash >/dev/null 2>&1 || die "helm install failed"
}
ensure_cilium_cli() {
  command -v cilium >/dev/null && return 0
  log "Installing cilium CLI $CILIUM_CLI_VERSION"
  curl -fsSL "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-amd64.tar.gz" | tar xz -C /usr/local/bin cilium || die "cilium CLI install failed"
}
ensure_hubble_cli() {
  command -v hubble >/dev/null && return 0
  log "Installing hubble CLI"
  curl -fsSL "https://github.com/cilium/hubble/releases/latest/download/hubble-linux-amd64.tar.gz" | tar xz -C /usr/local/bin hubble || die "hubble CLI install failed"
}
ensure_istioctl() {
  command -v istioctl >/dev/null && return 0
  log "Installing istioctl $ISTIO_VERSION"
  curl -fsSL "https://github.com/istio/istio/releases/download/${ISTIO_VERSION}/istioctl-${ISTIO_VERSION}-linux-amd64.tar.gz" | tar xz -C /usr/local/bin istioctl || die "istioctl install failed"
}
ensure_pkg() { # ensure_pkg <command> <apt-package>  (on both nodes)
  local cmd=$1 pkg=${2:-$1}
  command -v "$cmd" >/dev/null || { apt-get update -qq >/dev/null 2>&1; apt-get install -y -qq "$pkg" >/dev/null 2>&1; }
  n1 "command -v $cmd >/dev/null || { apt-get update -qq >/dev/null 2>&1; apt-get install -y -qq $pkg >/dev/null 2>&1; }" || true
}

# ── Platform installers (idempotent) ─────────────────────────────────
# Gateway API CRDs come with the Envoy Gateway chart, so every scenario that needs
# Gateway API (including Istio waypoints) goes through this one function.
ensure_envoy_gateway() {
  ensure_helm
  if ! kubectl -n envoy-gateway-system get deploy envoy-gateway >/dev/null 2>&1; then
    log "Installing Envoy Gateway $EG_VERSION (about 1-2 minutes)"
    helm install eg oci://docker.io/envoyproxy/gateway-helm --version "$EG_VERSION" \
      -n envoy-gateway-system --create-namespace >/dev/null || die "Envoy Gateway install failed"
  fi
  kubectl -n envoy-gateway-system wait --for=condition=Available deploy/envoy-gateway --timeout=240s >/dev/null || die "Envoy Gateway not available"
  kubectl apply -f - >/dev/null <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: eg
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
EOF
}

ensure_cert_manager() {
  if ! kubectl -n cert-manager get deploy cert-manager-webhook >/dev/null 2>&1; then
    log "Installing cert-manager $CERT_MANAGER_VERSION"
    kubectl apply -f "https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml" >/dev/null || die "cert-manager install failed"
  fi
  for d in cert-manager cert-manager-cainjector cert-manager-webhook; do
    kubectl -n cert-manager rollout status deploy/$d --timeout=240s >/dev/null || die "cert-manager not ready"
  done
}

ensure_istio_ambient() {
  require_no_bpf_masq
  ensure_istioctl
  ensure_envoy_gateway   # Gateway API CRDs (needed by waypoints)
  if ! kubectl -n istio-system get ds ztunnel >/dev/null 2>&1; then
    log "Installing Istio $ISTIO_VERSION (ambient profile, about 2 minutes)"
    istioctl install --set profile=ambient --skip-confirmation >/dev/null || die "istioctl install failed"
  fi
  kubectl -n istio-system rollout status ds/ztunnel --timeout=240s >/dev/null || die "ztunnel not ready"
  kubectl -n istio-system rollout status deploy/istiod --timeout=240s >/dev/null || die "istiod not ready"
}

# ── Test pod ("toolbox") ─────────────────────────────────────────────
# ensure_toolbox <namespace> [name] [serviceAccount]
ensure_toolbox() {
  local ns=$1 name=${2:-toolbox} sa=${3:-default}
  kubectl get ns "$ns" >/dev/null 2>&1 || kubectl create ns "$ns" >/dev/null
  if [ "$sa" != default ]; then kubectl -n "$ns" create sa "$sa" --dry-run=client -o yaml | kubectl apply -f - >/dev/null; fi
  kubectl -n "$ns" apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: $name
  labels: {app: $name}
spec:
  serviceAccountName: $sa
  tolerations: [{operator: Exists}]
  containers:
  - name: c
    image: curlimages/curl:8.8.0
    command: ["sleep", "infinity"]
EOF
}
wait_ready() { kubectl -n "$1" wait --for=condition=Ready "$2" --timeout="${3:-180s}" >/dev/null 2>&1; }  # wait_ready ns pod/name
# tbx <ns> <pod> <cmd...>  – run a command in a pod
tbx() { local ns=$1 pod=$2; shift 2; kubectl -n "$ns" exec "$pod" -- "$@"; }

# ── Gateway helpers (Envoy Gateway data plane) ───────────────────────
gw_svc() { kubectl -n envoy-gateway-system get svc -l "gateway.envoyproxy.io/owning-gateway-name=$2,gateway.envoyproxy.io/owning-gateway-namespace=$1" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null; }
# gw_forward <gw-ns> <gw-name> <service-port> <local-port>   (sets PF_PID)
gw_forward() {
  local ns=$1 gw=$2 rport=$3 lport=$4 svc i
  for i in $(seq 1 30); do svc=$(gw_svc "$ns" "$gw"); [ -n "$svc" ] && break; sleep 3; done
  [ -n "${svc:-}" ] || return 1
  kubectl -n envoy-gateway-system rollout status deploy -l "gateway.envoyproxy.io/owning-gateway-name=$gw,gateway.envoyproxy.io/owning-gateway-namespace=$ns" --timeout=150s >/dev/null 2>&1
  kubectl -n envoy-gateway-system port-forward "svc/$svc" "$lport:$rport" >/dev/null 2>&1 &
  PF_PID=$!
  sleep 3
  kill -0 "$PF_PID" 2>/dev/null
}
gw_forward_stop() { [ -n "${PF_PID:-}" ] && kill "$PF_PID" 2>/dev/null; PF_PID=""; }

# ── CoreDNS backup/restore (scenarios 12 and 13) ─────────────────────
coredns_backup() {
  [ -f "$STATE_DIR/Corefile.orig" ] || kubectl -n kube-system get cm coredns -o jsonpath='{.data.Corefile}' > "$STATE_DIR/Corefile.orig"
}
coredns_restore() {
  [ -f "$STATE_DIR/Corefile.orig" ] || return 0
  kubectl -n kube-system create cm coredns --from-file=Corefile="$STATE_DIR/Corefile.orig" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  kubectl -n kube-system rollout restart deploy coredns >/dev/null
}

# ── Calico removal + Cilium baseline (scenario 01 / install-cilium.sh) ─
wipe_calico() {
  log "Removing Calico and kube-proxy (simulating a cluster with no CNI)"
  kubectl delete installation default --ignore-not-found --wait=false >/dev/null 2>&1 || true
  kubectl -n tigera-operator delete deploy tigera-operator --ignore-not-found >/dev/null 2>&1 || true
  kubectl -n kube-system delete ds calico-node --ignore-not-found >/dev/null 2>&1 || true
  kubectl -n kube-system delete deploy calico-kube-controllers --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete ns calico-system calico-apiserver tigera-operator --ignore-not-found --wait=false >/dev/null 2>&1 || true
  kubectl -n kube-system delete ds kube-proxy --ignore-not-found >/dev/null 2>&1 || true
  kubectl -n kube-system delete cm kube-proxy --ignore-not-found >/dev/null 2>&1 || true
  on_all_nodes 'rm -f /etc/cni/net.d/*calico* /etc/cni/net.d/calico-kubeconfig
    iptables -F; iptables -t nat -F; iptables -t mangle -F; iptables -X; iptables -t nat -X; iptables -t mangle -X
    ip link del tunl0 2>/dev/null; ip link del vxlan.calico 2>/dev/null
    for i in $(ip -o link | awk -F": " "/cali/{print \$2}" | cut -d@ -f1); do ip link del "$i" 2>/dev/null; done; true'
}
# Remove an existing Cilium (the Killercoda playground may ship with one) and leave the nodes with no CNI.
wipe_cilium() {
  log "Removing the existing Cilium (simulating a cluster with no CNI)"
  cilium uninstall --wait >/dev/null 2>&1 || helm -n kube-system uninstall cilium >/dev/null 2>&1 || true
  kubectl -n kube-system delete ds cilium cilium-envoy --ignore-not-found >/dev/null 2>&1 || true
  kubectl -n kube-system delete deploy cilium-operator hubble-relay hubble-ui --ignore-not-found >/dev/null 2>&1 || true
  kubectl -n kube-system delete ds kube-proxy --ignore-not-found >/dev/null 2>&1 || true
  kubectl -n kube-system delete cm kube-proxy --ignore-not-found >/dev/null 2>&1 || true
  on_all_nodes 'rm -f /etc/cni/net.d/*cilium* /etc/cni/net.d/*.cilium_bak
    for i in cilium_host cilium_net cilium_vxlan cilium_wg0; do ip link del "$i" 2>/dev/null; done
    iptables -F; iptables -t nat -F; iptables -t mangle -F; iptables -X; iptables -t nat -X; iptables -t mangle -X; true'
}
cilium_baseline_install() {
  ensure_cilium_cli
  cilium install --version "$CILIUM_VERSION" \
    --set kubeProxyReplacement=true \
    --set k8sServiceHost="$(api_server_ip)" --set k8sServicePort=6443 \
    --set bpf.masquerade=true \
    --set cni.exclusive=false \
    --set operator.replicas=1
  cilium status --wait --wait-duration 6m
}

# ── Check-script framework ───────────────────────────────────────────
FAILED=0; N=0
check_header() { echo "=== Checking $1 ==="; echo; }
# check "description" <command...>   (the command runs in this shell, so functions work)
check() {
  local d=$1; shift; N=$((N + 1))
  printf 'CHECK %d: %s... ' "$N" "$d"
  if "$@" >/dev/null 2>&1; then echo PASS; else echo FAIL; FAILED=$((FAILED + 1)); fi
}
hint() { echo "    HINT: $*"; }
finish() {
  echo; echo "=== Results ==="
  if [ "$FAILED" -eq 0 ]; then echo "ALL CHECKS PASSED ✅"; exit 0; else echo "$FAILED CHECK(S) FAILED ❌"; exit 1; fi
}
# eq <actual> <expected>
eq() { [ -n "$1" ] && [ "$1" = "$2" ]; }
