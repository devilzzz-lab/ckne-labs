#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
need_cluster
echo "=== Setting up Scenario 02: IPAM and Pod CIDR investigation ==="
require_cilium
mkdir -p "$ANS_DIR"
rm -f "$ANS_DIR"/ipam-mode.txt "$ANS_DIR"/cluster-cidr.txt "$ANS_DIR"/node01-podcidr.txt "$ANS_DIR"/node01-cidr-source.txt
echo "Nothing to create. Answers go to $ANS_DIR."
echo "=== Setup complete. See TASK.md ==="
