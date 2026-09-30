#!/bin/bash
# Health check for nightglow.io on GitHub Pages: public DNS, HTTP->HTTPS and
# www redirects, status codes, certificate names/expiry, Pages settings.
# Requests are pinned to a Pages IP (via public DNS), so a stale local
# resolver cache cannot hide or fake the result.
# Usage: scripts/check-live.sh [domain]   (exit 1 on any failure)
set -uo pipefail

D="${1:-nightglow.io}"
REPO=micahstubbs/nightglow
fail=0
ok() { echo "PASS $*"; }
bad() { echo "FAIL $*"; fail=1; }

A=$(dig +short @1.1.1.1 A "$D" | sort | tr '\n' ' ')
[ "$A" = "185.199.108.153 185.199.109.153 185.199.110.153 185.199.111.153 " ] && ok "A records: $A" || bad "A records: '$A'"
[ "$(dig +short @1.1.1.1 AAAA "$D" | wc -l | tr -d ' ')" = 4 ] && ok "4 AAAA records" || bad "AAAA records"
W=$(dig +short @1.1.1.1 CNAME "www.$D")
[ "$W" = "micahstubbs.github.io." ] && ok "www CNAME $W" || bad "www CNAME '$W'"

IP=$(echo "$A" | cut -d' ' -f1)
probe() { # url expected_code expected_redirect
  local host=${1#*://}; host=${host%%/*}
  local port=80; [[ $1 == https* ]] && port=443
  local got
  got=$(curl -s -m 15 -o /dev/null --resolve "$host:$port:$IP" -w '%{http_code} %{redirect_url}' "$1")
  [ "$got" = "$2 $3" ] && ok "$1 -> $got" || bad "$1 -> '$got' (want '$2 $3')"
}
probe "http://$D/" 301 "https://$D/"
probe "http://www.$D/" 301 "https://$D/"
probe "https://www.$D/" 301 "https://$D/"
probe "https://$D/" 200 ""
probe "https://$D/js/main.js" 200 ""
probe "https://$D/assets/og.png" 200 ""

CERT=$(echo | openssl s_client -connect "$IP:443" -servername "$D" 2>/dev/null | openssl x509 -noout -ext subjectAltName -enddate 2>/dev/null)
grep -q "DNS:$D" <<< "$CERT" && grep -q "DNS:www.$D" <<< "$CERT" && ok "certificate covers $D and www" || bad "certificate names"
END=$(sed -n 's/notAfter=//p' <<< "$CERT")
DAYS=$(( ($(date -j -f '%b %d %T %Y %Z' "$END" +%s) - $(date +%s)) / 86400 ))
[ "$DAYS" -gt 14 ] && ok "certificate valid $DAYS more days ($END)" || bad "certificate expires in $DAYS days"

PAGES=$(gh api "repos/$REPO/pages" -q '"\(.status) \(.https_enforced) \(.https_certificate.state) \(.cname)"')
[ "$PAGES" = "built true approved $D" ] && ok "Pages: $PAGES" || bad "Pages: $PAGES"

if curl -s -m 10 -o /dev/null "https://$D/"; then ok "this machine resolves $D"
else echo "NOTE this machine cannot resolve $D ($(dig +short "$D" | head -1)); check its resolver cache, not the site"; fi
exit $fail
