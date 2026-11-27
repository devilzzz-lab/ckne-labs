#!/usr/bin/env bash
echo "=== Cleaning up Scenario 10 ==="
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
kubectl delete ns lb-lab --ignore-not-found
kubectl -n metallb-system delete ipaddresspools,l2advertisements --all --ignore-not-found 2>/dev/null || true
kubectl delete -f "https://raw.githubusercontent.com/metallb/metallb/${METALLB_VERSION}/config/manifests/metallb-native.yaml" --ignore-not-found >/dev/null 2>&1 || true
echo "=== Cleanup complete ==="
