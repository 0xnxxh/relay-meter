#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/version.sh"

echo "release-check: publish workflow"
"$ROOT_DIR/scripts/test_publish_release.sh"

echo "release-check: characterization tests"
"$ROOT_DIR/scripts/run_characterization_tests.sh"

echo "release-check: app bundle"
APP_BUNDLE="$("$ROOT_DIR/scripts/build_and_run.sh" build)"
echo "release-check: DMG"
DMG_PATH="$("$ROOT_DIR/scripts/package_dmg.sh")"
echo "release-check: Sparkle appcast"
APPCAST_PATH="$("$ROOT_DIR/scripts/generate_appcast.sh")"

echo "release-check: bundle and archive validation"
/usr/bin/plutil -lint "$APP_BUNDLE/Contents/Info.plist" >/dev/null
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE" >/dev/null
/usr/bin/hdiutil verify "$DMG_PATH" >/dev/null

if ! grep -q "Relay-Meter-v$APP_VERSION.dmg" "$APPCAST_PATH"; then
  echo "appcast does not reference Relay-Meter-v$APP_VERSION.dmg" >&2
  exit 1
fi

if ! grep -q "https://github.com/0xnxxh/relay-meter/releases/download/v$APP_VERSION/Relay-Meter-v$APP_VERSION.dmg" "$APPCAST_PATH"; then
  echo "appcast does not reference the versioned GitHub Release asset URL" >&2
  exit 1
fi

echo "app=$APP_BUNDLE"
echo "dmg=$DMG_PATH"
echo "appcast=$APPCAST_PATH"
echo "release-check: complete"
