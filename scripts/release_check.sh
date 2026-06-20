#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/version.sh"

APP_BUNDLE="$("$ROOT_DIR/scripts/build_and_run.sh" build)"
DMG_PATH="$("$ROOT_DIR/scripts/package_dmg.sh")"
APPCAST_PATH="$("$ROOT_DIR/scripts/generate_appcast.sh")"

/usr/bin/plutil -lint "$APP_BUNDLE/Contents/Info.plist" >/dev/null
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE" >/dev/null
/usr/bin/hdiutil verify "$DMG_PATH" >/dev/null

if ! grep -q "CPA-Menubar-v$APP_VERSION.dmg" "$APPCAST_PATH"; then
  echo "appcast does not reference CPA-Menubar-v$APP_VERSION.dmg" >&2
  exit 1
fi

if ! grep -q "https://github.com/0xnxxh/cpa-menubar/releases/download/v$APP_VERSION/CPA-Menubar-v$APP_VERSION.dmg" "$APPCAST_PATH"; then
  echo "appcast does not reference the versioned GitHub Release asset URL" >&2
  exit 1
fi

echo "app=$APP_BUNDLE"
echo "dmg=$DMG_PATH"
echo "appcast=$APPCAST_PATH"
