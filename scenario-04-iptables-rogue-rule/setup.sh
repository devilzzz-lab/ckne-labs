#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
need_cluster
echo "=== Setting up Scenario 04: Find and remove a rogue iptables rule ==="
ensure_pkg iptables
ensure_pkg python3

N1IP=$(node_ip node01)
CPIP=$(ip route get "$N1IP" | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}' | head -1)
state_set s04-n1ip "$N1IP"; state_set s04-cpip "$CPIP"

n1 'mkdir -p /srv/ckne-web && echo ckne-web-ok > /srv/ckne-web/index.html
    systemctl stop ckne-web 2>/dev/null; systemctl reset-failed ckne-web 2>/dev/null
    systemd-run --unit=ckne-web --quiet python3 -m http.server 9090 --bind 0.0.0.0 -d /srv/ckne-web'
# Remove any previous lab rules, then add: 1 rogue rule + 2 decoys that must stay.
n1 "iptables -S INPUT | grep -E 'ckne-' | sed 's/^-A/-D/' | while read -r r; do iptables \$r; done; true"
n1 "iptables -I INPUT 1 -p tcp -s $CPIP --dport 9090 -m comment --comment ckne-maintenance -j DROP
    iptables -I INPUT 1 -p tcp --dport 9099 -m comment --comment ckne-legacy-keep -j DROP
    iptables -I INPUT 1 -p udp --dport 9098 -m comment --comment ckne-metrics-keep -j DROP"
sleep 2
if curl -s -m3 "http://$N1IP:9090" >/dev/null; then warn "curl unexpectedly works. The rule was not applied."; else log "Confirmed: curl to node01:9090 times out."; fi
echo "node01 IP: $N1IP"
echo "=== Setup complete. See TASK.md ==="
