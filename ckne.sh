#!/usr/bin/env bash
set -uo pipefail

# CKNE Practice Labs - Interactive Sequential Study Mode
# Usage: ./ckne.sh [scenario_number]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROGRESS_FILE="$SCRIPT_DIR/.ckne-progress"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

# Session tags:  any    = works on both Calico (A) and Cilium (B)
#                cilium = needs Cilium (session B)
#                calico = needs a non-Cilium-bpf-masq cluster (session A) - Istio ambient
SCENARIOS=(
  "scenario-01-cilium-install-kpr"
  "scenario-02-ipam-podcidr"
  "scenario-03-tcpdump-capture"
  "scenario-04-iptables-rogue-rule"
  "scenario-05-tc-netem-latency"
  "scenario-06-pod-dns-config"
  "scenario-07-multus-dual-nic"
  "scenario-08-service-types"
  "scenario-09-selectorless-endpointslice"
  "scenario-10-loadbalancer-metallb"
  "scenario-11-kube-proxy-mode"
  "scenario-12-coredns-forward-corp"
  "scenario-13-coredns-external-fix"
  "scenario-14-service-no-endpoints"
  "scenario-15-gateway-path-routing"
  "scenario-16-gateway-troubleshoot"
  "scenario-17-inference-pool"
  "scenario-18-cilium-bgp"
  "scenario-19-cilium-egress-gateway"
  "scenario-20-clustermesh-repair"
  "scenario-21-istio-registry-only-egress"
  "scenario-22-netpol-default-deny"
  "scenario-23-cilium-l7-policy"
  "scenario-24-cilium-fqdn-egress"
  "scenario-25-wireguard-encryption"
  "scenario-26-gateway-tls-secret"
  "scenario-27-certmanager-gateway"
  "scenario-28-gateway-tls-broken"
  "scenario-29-istio-ambient-strict-mtls"
  "scenario-30-istio-authz-waypoint-l7"
  "scenario-31-hubble-drops"
  "scenario-32-prometheus-bad-pod"
  "scenario-33-jaeger-slow-hop"
  "scenario-34-envoy-access-logs"
)
SCENARIO_TITLES=(
  "Install Cilium with kube-proxy replacement"
  "IPAM and Pod CIDR investigation"
  "Capture packets with tcpdump"
  "Find and remove a rogue iptables rule"
  "Find and remove injected latency (tc netem)"
  "Fix a Pod that cannot resolve cluster DNS"
  "Multi-interface Pod with Multus"
  "ClusterIP / NodePort / Headless / ExternalName"
  "Service without selector + EndpointSlice"
  "LoadBalancer Service with MetalLB"
  "Which proxy programs Services?"
  "CoreDNS: forward a corporate domain"
  "CoreDNS: fix external lookups"
  "Service with no endpoints + readiness probe"
  "Gateway API path routing"
  "Gateway API: fix a broken route"
  "Inference Gateway: InferencePool routing"
  "Cilium BGP Control Plane"
  "Cilium Egress Gateway"
  "Cluster Mesh: repair the configuration"
  "Istio: registry-only egress control"
  "NetworkPolicy: default deny + allow-list"
  "Cilium L7 HTTP policy"
  "Cilium FQDN egress policy"
  "WireGuard pod + node encryption"
  "Gateway HTTPS with a TLS Secret"
  "cert-manager issues the Gateway cert"
  "Gateway TLS: fix a broken setup"
  "Istio ambient: STRICT mTLS"
  "Istio ambient: waypoint + L7 AuthorizationPolicy"
  "Hubble: find the dropped workload"
  "Prometheus: find the failing backend pod"
  "Jaeger: find the slow hop and the error"
  "Envoy access logs: who is hitting /api/login?"
)
SCENARIO_MODES=(
  cilium cilium any any any any any
  any any any any any any any any any
  any cilium cilium any calico
  any cilium cilium cilium any any any calico calico
  cilium any any any
)
SCENARIO_DOMAINS=(
  1 1 1 1 1 1 1
  2 2 2 2 2 2 2 2 2
  3 3 3 3 3
  4 4 4 4 4 4 4 4 4
  5 5 5 5
)
DOMAIN_FILES=(
  ""
  "study/01-core-infrastructure-cni.md"
  "study/02-service-networking-dns.md"
  "study/03-advanced-traffic-management.md"
  "study/04-network-security-policy.md"
  "study/05-observability.md"
)

CURRENT=0
COMPLETED=()
SCENARIO_ACTIVE=false
TOTAL=${#SCENARIOS[@]}
LAST_INDEX=$((TOTAL - 1))

# Sanity: all parallel arrays must have the same length.
for arr in SCENARIO_TITLES SCENARIO_MODES SCENARIO_DOMAINS; do
  n=$(eval "echo \${#${arr}[@]}")
  if [ "$n" -ne "$TOTAL" ]; then echo "Internal error: $arr has $n entries, expected $TOTAL" >&2; exit 1; fi
done

# ─── Progress ──────────────────────────────────────────────────────
load_progress() { CURRENT=0; COMPLETED=(); [ -f "$PROGRESS_FILE" ] && source "$PROGRESS_FILE"; }
save_progress() {
  {
    echo "CURRENT=$CURRENT"
    if [ ${#COMPLETED[@]} -gt 0 ]; then echo "COMPLETED=(${COMPLETED[*]})"; else echo "COMPLETED=()"; fi
  } > "$PROGRESS_FILE"
}
is_completed() {
  [ ${#COMPLETED[@]} -eq 0 ] && return 1
  for c in "${COMPLETED[@]}"; do [ "$c" = "$1" ] && return 0; done
  return 1
}
mark_completed() { is_completed "$1" || { COMPLETED+=("$1"); save_progress; }; }
reset_all_progress() { CURRENT=0; COMPLETED=(); rm -f "$PROGRESS_FILE"; }

# ─── Display ───────────────────────────────────────────────────────
clear_screen() { printf '\033[2J\033[H'; }

mode_label() {
  case "$1" in
    cilium) echo -e "${CYAN}[B: Cilium]${NC}" ;;
    calico) echo -e "${YELLOW}[A: Calico, Istio]${NC}" ;;
    *)      echo -e "${DIM}[A or B]${NC}" ;;
  esac
}

show_header() {
  local idx=$CURRENT numstr
  numstr=$(printf "%02d" $((idx + 1)))
  echo -e "${BOLD}${CYAN}"
  echo "╔═══════════════════════════════════════════════════════════════╗"
  echo "║             CKNE Practice Labs - Study Mode                   ║"
  echo "╚═══════════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
  echo -e "  Progress: ${GREEN}${#COMPLETED[@]}${NC}/${TOTAL} completed"
  echo ""
  local mark=""; is_completed "$idx" && mark=" ✓"
  echo -e "  ${YELLOW}▶ Scenario ${numstr}/${TOTAL}: ${SCENARIO_TITLES[$idx]}${mark}${NC}"
  echo -e "    Domain ${SCENARIO_DOMAINS[$idx]}   $(mode_label "${SCENARIO_MODES[$idx]}")"
  echo ""
}

show_menu() {
  echo -e "  ${BOLD}Options:${NC}"
  echo -e "    ${CYAN}[r]${NC} Run/Setup this scenario"
  echo -e "    ${CYAN}[t]${NC} Show Task (question)"
  echo -e "    ${CYAN}[s]${NC} Show Solution"
  echo -e "    ${CYAN}[c]${NC} Check my answer"
  echo -e "    ${CYAN}[g]${NC} Open the study guide for this domain"
  echo -e "    ${CYAN}[x]${NC} Reset (cleanup) this scenario"
  echo -e "    ${CYAN}[f]${NC} Full reset (cleans ALL scenarios)"
  echo -e "    ${CYAN}[d]${NC} Mark done & next →"
  echo -e "    ${CYAN}[n]${NC} Next scenario →"
  echo -e "    ${CYAN}[p]${NC} Previous scenario ←"
  echo -e "    ${CYAN}[l]${NC} List all scenarios"
  echo -e "    ${CYAN}[q]${NC} Quit"
  echo ""
}

show_file() { # title color file
  echo ""
  echo -e "${BOLD}$2━━━ $1 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  if [ -f "$3" ]; then echo ""; cat "$3"; else echo -e "${RED}  Missing: $3${NC}"; fi
  echo ""
  echo -e "${BOLD}$2━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
}
show_task()     { show_file TASK "$BLUE" "$SCRIPT_DIR/${SCENARIOS[$CURRENT]}/TASK.md"; }
show_solution() { show_file SOLUTION "$GREEN" "$SCRIPT_DIR/${SCENARIOS[$CURRENT]}/solution.md"; }

open_study() {
  local f="$SCRIPT_DIR/${DOMAIN_FILES[${SCENARIO_DOMAINS[$CURRENT]}]}"
  if [ -f "$f" ]; then "${PAGER:-less}" -R "$f"; else echo "  Missing $f"; wait_enter; fi
}

# ─── Actions ───────────────────────────────────────────────────────
do_setup() {
  local dir="$SCRIPT_DIR/${SCENARIOS[$CURRENT]}"
  [ -f "$dir/setup.sh" ] || { echo -e "  ${RED}No setup.sh found.${NC}"; wait_enter; return; }

  if ! kubectl get nodes --request-timeout=5s &>/dev/null; then
    echo -e "\n  ${RED}${BOLD}ERROR: Cannot connect to the cluster!${NC}\n"
    echo -e "  ${DIM}Is the API server up?${NC}  ${CYAN}crictl ps | grep kube-apiserver${NC}"
    echo -e "  ${DIM}Restart kubelet:${NC}      ${CYAN}systemctl restart kubelet; sleep 30; kubectl get nodes${NC}\n"
    wait_enter; return
  fi

  echo -e "\n  ${YELLOW}Setting up scenario...${NC}\n"
  if bash "$dir/setup.sh"; then
    SCENARIO_ACTIVE=true
    echo -e "\n  ${GREEN}✓ Scenario is ready!${NC}\n"
    show_task
  else
    echo -e "\n  ${RED}✗ Setup failed. Read the message above, fix it, then press [x] and [r] again.${NC}\n"
    wait_enter; return
  fi

  while true; do
    echo -e "  ${BOLD}${YELLOW}>>> Solve this in another terminal <<<${NC}\n"
    echo -e "  ${CYAN}[t]${NC} Task  ${CYAN}[s]${NC} Solution  ${CYAN}[c]${NC} Check  ${CYAN}[b]${NC} Back to menu\n"
    echo -ne "  ${BOLD}Choice: ${NC}"
    read -r -n1 sub || return; echo ""
    case "$sub" in
      t|T) show_task ;;
      s|S) show_solution ;;
      c|C) do_check_inline ;;
      b|B|"") return ;;
    esac
  done
}

do_check_inline() {
  local dir="$SCRIPT_DIR/${SCENARIOS[$CURRENT]}"
  echo ""
  if [ -f "$dir/check.sh" ]; then
    echo -e "  ${YELLOW}Checking your answer...${NC}\n"
    if bash "$dir/check.sh"; then
      echo -e "\n  ${GREEN}${BOLD}✓ All checks passed! Well done!${NC}"
    else
      echo -e "\n  ${RED}✗ Some checks failed. Keep trying or view the solution [s].${NC}"
    fi
  else
    echo -e "  ${DIM}No automated check. Compare with the solution [s].${NC}"
  fi
  echo ""
}
do_check() { do_check_inline; wait_enter; }

do_reset() {
  local dir="$SCRIPT_DIR/${SCENARIOS[$CURRENT]}"
  echo ""
  if [ -f "$dir/cleanup.sh" ]; then
    echo -e "  ${YELLOW}Cleaning up scenario...${NC}"
    bash "$dir/cleanup.sh" 2>/dev/null || true
    SCENARIO_ACTIVE=false
    echo -e "  ${GREEN}✓ Scenario reset.${NC}"
  else
    echo -e "  ${RED}No cleanup.sh found.${NC}"
  fi
  echo ""; wait_enter
}

do_full_reset() {
  echo -e "\n  ${YELLOW}${BOLD}FULL RESET${NC}"
  echo -e "  ${DIM}Runs cleanup for ALL scenarios. CNI changes (01, 25) are not undone: restart the playground for that.${NC}\n"
  echo -ne "  ${BOLD}Are you sure? [y/N]: ${NC}"
  read -r confirm || confirm=n; echo ""
  case "$confirm" in
    y|Y)
      for s in "${SCENARIOS[@]}"; do
        if [ -f "$SCRIPT_DIR/$s/cleanup.sh" ]; then
          echo -e "  ${DIM}→ cleaning $s${NC}"
          bash "$SCRIPT_DIR/$s/cleanup.sh" >/dev/null 2>&1 || true
        fi
      done
      SCENARIO_ACTIVE=false
      if kubectl get nodes --request-timeout=5s >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓ API server reachable${NC}"; kubectl get nodes 2>/dev/null | sed 's/^/    /'
      else
        echo -e "  ${RED}✗ API server not reachable.${NC}"
      fi
      echo -e "\n  ${GREEN}${BOLD}✓ Reset done.${NC}" ;;
    *) echo -e "  ${DIM}Cancelled.${NC}" ;;
  esac
  echo ""; wait_enter
}

do_quit() {
  echo ""
  if [ "$SCENARIO_ACTIVE" = true ]; then
    local dir="$SCRIPT_DIR/${SCENARIOS[$CURRENT]}"
    [ -f "$dir/cleanup.sh" ] && { echo -e "  ${YELLOW}Cleaning up active scenario...${NC}"; bash "$dir/cleanup.sh" 2>/dev/null || true; }
  fi
  echo -e "\n  ${BOLD}Before quitting:${NC}"
  echo -e "    ${CYAN}[s]${NC} Save progress and quit"
  echo -e "    ${CYAN}[r]${NC} Reset ALL progress and quit"
  echo -e "    ${CYAN}[c]${NC} Cancel (go back)\n"
  echo -ne "  ${BOLD}Choice: ${NC}"
  read -r -n1 q || exit 0; echo ""
  case "$q" in
    s|S) save_progress; echo -e "\n  ${GREEN}Progress saved (${#COMPLETED[@]}/${TOTAL}). Good luck with CKNE! 🎯${NC}\n"; exit 0 ;;
    r|R) reset_all_progress; echo -e "\n  ${YELLOW}All progress reset.${NC}\n"; exit 0 ;;
    *) return ;;
  esac
}

list_scenarios() {
  echo -e "\n  ${BOLD}All ${TOTAL} CKNE scenarios:${NC}   (A = Calico session, B = Cilium session)\n"
  local d=0
  for i in "${!SCENARIOS[@]}"; do
    if [ "${SCENARIO_DOMAINS[$i]}" != "$d" ]; then
      d=${SCENARIO_DOMAINS[$i]}
      case $d in
        1) echo -e "    ${BOLD}Domain 1: Core Infrastructure and CNI (15%)${NC}" ;;
        2) echo -e "    ${BOLD}Domain 2: Service Networking and DNS (25%)${NC}" ;;
        3) echo -e "    ${BOLD}Domain 3: Advanced Traffic Management (20%)${NC}" ;;
        4) echo -e "    ${BOLD}Domain 4: Network Security and Policy (25%)${NC}" ;;
        5) echo -e "    ${BOLD}Domain 5: Observability (15%)${NC}" ;;
      esac
    fi
    local marker="  " color="$NC" mark=""
    [ "$i" -eq "$CURRENT" ] && { marker="▶ "; color="$YELLOW"; }
    is_completed "$i" && { color="$GREEN"; mark=" ✓"; }
    echo -e "    ${color}${marker}$(printf '%02d' $((i + 1))). ${SCENARIO_TITLES[$i]}${mark}${NC} $(mode_label "${SCENARIO_MODES[$i]}")"
  done
  echo ""; wait_enter
}

next_scenario() { if [ "$CURRENT" -lt "$LAST_INDEX" ]; then CURRENT=$((CURRENT + 1)); save_progress; else echo -e "\n  ${GREEN}${BOLD}🎉 Last scenario already!${NC}\n"; sleep 1; fi; }
prev_scenario() { [ "$CURRENT" -gt 0 ] && { CURRENT=$((CURRENT - 1)); save_progress; }; }
wait_enter()    { echo -ne "  ${DIM}Press Enter to continue...${NC}"; read -r; }

main() {
  load_progress
  if [ -n "${1:-}" ] && [[ "$1" =~ ^[0-9]+$ ]]; then
    local target=$((10#$1 - 1))
    if [ "$target" -ge 0 ] && [ "$target" -le "$LAST_INDEX" ]; then CURRENT=$target; save_progress; fi
  fi
  while true; do
    clear_screen; show_header; show_menu
    echo -ne "  ${BOLD}Choice: ${NC}"
    read -r -n1 choice || { echo; exit 0; }; echo ""
    case "$choice" in
      r|R) do_setup ;;
      t|T) show_task; wait_enter ;;
      s|S) show_solution; wait_enter ;;
      c|C) do_check ;;
      g|G) open_study ;;
      x|X) do_reset ;;
      f|F) do_full_reset ;;
      d|D) mark_completed "$CURRENT"; next_scenario ;;
      n|N) next_scenario ;;
      p|P) prev_scenario ;;
      l|L) list_scenarios ;;
      q|Q) do_quit ;;
    esac
  done
}

main "$@"
