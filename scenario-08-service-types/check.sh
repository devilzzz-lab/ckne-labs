#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
check_header "Scenario 08: Service types"
S() { kubectl -n svc-lab get svc "$1" -o jsonpath="$2" 2>/dev/null; }
N1IP=$(node_ip node01)

cip_cfg() { eq "$(S web-clusterip '{.spec.type}')" ClusterIP && eq "$(S web-clusterip '{.spec.ports[0].port}')" 8080 && eq "$(S web-clusterip '{.spec.ports[0].targetPort}')" 80 && eq "$(S web-clusterip '{.spec.selector.app}')" web; }
cip_fn()  { tbx svc-lab toolbox curl -s -m5 http://web-clusterip:8080 | grep -qi nginx; }
np_cfg()  { eq "$(S web-nodeport '{.spec.type}')" NodePort && eq "$(S web-nodeport '{.spec.ports[0].nodePort}')" 30088 && eq "$(S web-nodeport '{.spec.ports[0].port}')" 80; }
np_fn()   { curl -s -m5 "http://$N1IP:30088" | grep -qi nginx; }
hl_cfg()  { eq "$(S web-headless '{.spec.clusterIP}')" None && eq "$(S web-headless '{.spec.selector.app}')" web; }
hl_fn()   { [ "$(tbx svc-lab toolbox nslookup web-headless.svc-lab.svc.cluster.local | awk '/^Name:/{f=1} f && /^Address/' | wc -l)" -ge 2 ]; }
en_cfg()  { eq "$(S docs '{.spec.type}')" ExternalName && eq "$(S docs '{.spec.externalName}')" kubernetes.io; }
en_fn()   { tbx svc-lab toolbox nslookup docs.svc-lab.svc.cluster.local | grep -qi 'kubernetes.io'; }

check "web-clusterip: ClusterIP 8080 -> 80, selector app=web" cip_cfg
check "web-clusterip answers from inside the cluster" cip_fn
check "web-nodeport: NodePort 80 -> 80 with nodePort 30088" np_cfg
check "web-nodeport answers on node01:30088" np_fn
check "web-headless: clusterIP None, selector app=web" hl_cfg
check "web-headless DNS returns more than one Pod IP" hl_fn
check "docs: ExternalName kubernetes.io" en_cfg
check "docs resolves to a CNAME for kubernetes.io" en_fn
finish
