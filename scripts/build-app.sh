#!/bin/bash
# Build Nightglow.app (release, ad-hoc signed) and optionally install it.
# Usage: scripts/build-app.sh [--install] [--open]
#   --install  copy to ~/Applications/Nightglow.app (quits a running copy first)
#   --open     launch the built (or installed) app
set -euo pipefail

cd "$(dirname "$0")/.."
INSTALL=0
OPEN=0
for arg in "$@"; do
  case "$arg" in
    --install) INSTALL=1 ;;
    --open) OPEN=1 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

VERSION=$(git describe --tags --always 2>/dev/null || echo 0)
APP=build/Nightglow.app

swift build -c release --arch arm64 --arch x86_64
BIN=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/Nightglow

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Nightglow"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>fyi.micah.nightglow</string>
  <key>CFBundleName</key><string>Nightglow</string>
  <key>CFBundleDisplayName</key><string>Nightglow</string>
  <key>CFBundleExecutable</key><string>Nightglow</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSLocationUsageDescription</key><string>Nightglow uses your approximate location to know when the sun rises and sets.</string>
  <key>NSLocationWhenInUseUsageDescription</key><string>Nightglow uses your approximate location to know when the sun rises and sets.</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
codesign --verify "$APP"
echo "Built $APP ($VERSION, $(lipo -archs "$APP/Contents/MacOS/Nightglow"))"

TARGET="$APP"
if [ "$INSTALL" = 1 ]; then
  pkill -x Nightglow 2>/dev/null && sleep 1 || true
  mkdir -p "$HOME/Applications"
  rsync -a --delete "$APP/" "$HOME/Applications/Nightglow.app/"
  TARGET="$HOME/Applications/Nightglow.app"
  echo "Installed $TARGET"
fi

if [ "$OPEN" = 1 ]; then
  open "$TARGET"
  sleep 2
  pgrep -x Nightglow >/dev/null && echo "Nightglow is running (pid $(pgrep -x Nightglow))" \
    || { echo "Nightglow failed to start" >&2; exit 1; }
fi
