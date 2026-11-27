#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
check_header "Scenario 03: Capture packets with tcpdump"
F=/opt/captures/api.pcap

exists()   { n1 "test -s $F"; }
count()    { eq "$(n1 "tcpdump -nn -r $F 2>/dev/null | wc -l" | tr -d ' ')" 25; }
alldst()   { eq "$(n1 "tcpdump -nn -r $F 'dst port 8080' 2>/dev/null | wc -l" | tr -d ' ')" 25; }
validpcap() { n1 "tcpdump -nn -r $F >/dev/null 2>&1"; }

check "$F exists on node01 and is not empty" exists
check "It is a readable pcap file" validpcap
check "It contains exactly 25 packets" count
check "All 25 packets have destination port 8080" alldst
finish
