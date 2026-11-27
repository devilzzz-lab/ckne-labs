#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
check_header "Scenario 31: Hubble drops"
B=$(state_get s31-blocked)

src_ok()     { eq "$(ans dropped-source.txt)" "$B"; }
reason_ok()  { ans drop-reason.txt | grep -qiE 'policy[ _]denied'; }   # text form or JSON enum
b_works()    { retry 6 3 bash -c "[ \"\$(kubectl -n finance exec deploy/$B -- curl -s -m3 http://db:5432)\" = db-ok ]"; }
others_ok()  { local a; for a in app-a app-b app-c; do [ "$a" = "$B" ] && continue; [ "$(kubectl -n finance exec deploy/$a -- curl -s -m3 http://db:5432)" = db-ok ] || return 1; done; }
no_allowall(){ ! kubectl -n finance get cnp -o yaml | grep -Eq 'toEntities|fromEntities|0\.0\.0\.0/0|fromCIDR|reserved:world|- *\{\}'; }
still_closed(){ ! kubectl -n finance run probe-$RANDOM --rm -i --restart=Never --image=curlimages/curl:8.8.0 -- curl -s -m3 http://db:5432 2>/dev/null | grep -q db-ok; }

check "dropped-source.txt names the blocked client ($B)" src_ok
check "drop-reason.txt says 'Policy denied' (or POLICY_DENIED)" reason_ok
check "$B can now reach db:5432" b_works
check "The other two clients still reach db" others_ok
check "No allow-all rule was added (no entities / CIDR / world)" no_allowall
check "An unrelated Pod without a matching label is still blocked" still_closed
finish
