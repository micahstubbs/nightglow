#!/bin/bash
# Point nightglow.io (Spaceship DNS) at GitHub Pages: apex A/AAAA to the
# Pages anycast addresses, www CNAME to the owner's github.io host.
# Idempotent: records that already exist are skipped. Uses the spaceship-dns
# helper (~/.claude/scripts/spaceship-dns.sh, key in ~/keys/spaceship/).
# Usage: scripts/configure-dns.sh [--check]
set -uo pipefail

DOMAIN=nightglow.io
OWNER_HOST=micahstubbs.github.io
DNS=~/.claude/scripts/spaceship-dns.sh
A=(185.199.108.153 185.199.109.153 185.199.110.153 185.199.111.153)
AAAA=(2606:50c0:8000::153 2606:50c0:8001::153 2606:50c0:8002::153 2606:50c0:8003::153)

if [ "${1:-}" = "--check" ]; then
  echo "Spaceship records:"; "$DNS" list "$DOMAIN"
  echo "Public DNS (1.1.1.1):"
  for t in A AAAA; do echo "  @ $t: $(dig +short @1.1.1.1 $t $DOMAIN | sort | tr '\n' ' ')"; done
  echo "  www CNAME: $(dig +short @1.1.1.1 CNAME www.$DOMAIN)"
  exit 0
fi

existing=$("$DNS" list "$DOMAIN" 2>/dev/null || true)
add() { # type name value
  if grep -qF "$3" <<< "$existing"; then echo "exists: $1 $2 $3"; return; fi
  "$DNS" set "$DOMAIN" "$1" "$2" "$3" 600 | tail -1
}
for ip in "${A[@]}"; do add A @ "$ip"; done
for ip in "${AAAA[@]}"; do add AAAA @ "$ip"; done
add CNAME www "$OWNER_HOST"
