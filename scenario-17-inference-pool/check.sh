#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
check_header "Scenario 17: Inference Gateway"
P() { kubectl -n inference get inferencepools.inference.networking.k8s.io llama-pool -o jsonpath="$1" 2>/dev/null; }
R() { kubectl -n inference get httproute llm-route -o jsonpath="$1" 2>/dev/null; }

pool_exists() { kubectl -n inference get inferencepools.inference.networking.k8s.io llama-pool; }
pool_sel()    { eq "$(P '{.spec.selector.matchLabels.app}')" vllm-llama; }
pool_port()   { eq "$(P '{.spec.targetPorts[0].number}')" 8000; }
pool_epp()    { eq "$(P '{.spec.endpointPickerRef.name}')" llama-epp && eq "$(P '{.spec.endpointPickerRef.port.number}')" 9002; }
route_exists(){ kubectl -n inference get httproute llm-route; }
route_parent(){ eq "$(R '{.spec.parentRefs[0].name}')" inference-gw; }
route_match() { eq "$(R '{.spec.rules[0].matches[0].path.value}')" /v1/completions && eq "$(R '{.spec.rules[0].matches[0].method}')" POST; }
route_pool()  { eq "$(R '{.spec.rules[0].backendRefs[0].kind}')" InferencePool && eq "$(R '{.spec.rules[0].backendRefs[0].name}')" llama-pool && eq "$(R '{.spec.rules[0].backendRefs[0].group}')" inference.networking.k8s.io; }

check "InferencePool llama-pool exists" pool_exists
check "Pool selects app=vllm-llama" pool_sel
check "Pool targets port 8000" pool_port
check "Pool endpointPickerRef is llama-epp:9002" pool_epp
check "HTTPRoute llm-route exists" route_exists
check "Route is attached to Gateway inference-gw" route_parent
check "Route matches POST + PathPrefix /v1/completions" route_match
check "Route backendRef is the InferencePool llama-pool (group inference.networking.k8s.io)" route_pool
finish
