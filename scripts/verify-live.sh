#!/bin/bash
# Drive the running Nightglow.app through its menu (System Events) and check
# the live gamma tables after each action. Needs Accessibility permission
# for the terminal. Usage: scripts/verify-live.sh [path/to/Nightglow.app]
set -uo pipefail

APP="${1:-$HOME/Applications/Nightglow.app}"
BIN="$APP/Contents/MacOS/Nightglow"
pgrep -x Nightglow >/dev/null || { open "$APP"; sleep 3; }

click() {
  osascript -e "tell application \"System Events\" to tell process \"Nightglow\"
    click menu bar item 1 of menu bar 1
    delay 0.4
    click menu item \"$1\" of menu 1 of menu bar item 1 of menu bar 1
  end tell" >/dev/null
}
blue() { "$BIN" --gamma | head -1 | sed -E 's/.*b=([0-9.]+).*/\1/'; }
fail=0
check() { # name, condition on $b
  local b; b=$(blue)
  if awk -v b="$b" "BEGIN { exit !($2) }"; then echo "PASS $1 (blue $b)"; else echo "FAIL $1 (blue $b)"; fail=1; fi
}

"$BIN" --status | sed -n '2p;6p'
expect_warm=$("$BIN" --status | awk '/^target:/ { print ($2 < 6400) }')
if [ "$expect_warm" = 1 ]; then check "running app tints displays" 'b < 0.95'
else check "running app leaves daytime displays neutral" 'b > 0.99'; fi

click "Disable for an Hour"; sleep 2.5
check "pause fades to neutral" 'b > 0.99'
click "Resume Now"; sleep 2.5
if [ "$expect_warm" = 1 ]; then check "resume restores tint" 'b < 0.95'; fi

click "Preview 24 Hours"; lo=1; hi=0
for _ in $(seq 1 26); do
  sleep 0.5; b=$(blue)
  lo=$(awk -v a="$lo" -v b="$b" 'BEGIN { print (b < a ? b : a) }')
  hi=$(awk -v a="$hi" -v b="$b" 'BEGIN { print (b > a ? b : a) }')
done
sleep 1
awk -v lo="$lo" -v hi="$hi" 'BEGIN { exit !(lo < 0.9 && hi > 0.99) }' \
  && echo "PASS preview sweeps day and night (blue $lo..$hi)" \
  || { echo "FAIL preview (blue $lo..$hi)"; fail=1; }
exit $fail
