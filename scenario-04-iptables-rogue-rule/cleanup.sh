#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
echo "=== Cleaning up Scenario 04 ==="
n1 "iptables -S INPUT | grep -E 'ckne-' | sed 's/^-A/-D/' | while read -r r; do iptables \$r; done; true" || true
n1 'systemctl stop ckne-web 2>/dev/null; systemctl reset-failed ckne-web 2>/dev/null; rm -rf /srv/ckne-web; true' || true
echo "=== Cleanup complete ==="
