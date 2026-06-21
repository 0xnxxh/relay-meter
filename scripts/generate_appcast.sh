#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/version.sh"

SPARKLE_DIR="$("$ROOT_DIR/scripts/ensure_sparkle.sh")"
GENERATE_APPCAST="$SPARKLE_DIR/bin/generate_appcast"
PRIVATE_KEY="${SPARKLE_PRIVATE_KEY:-$ROOT_DIR/sparkle_private_key}"
ACCOUNT="${SPARKLE_KEY_ACCOUNT:-0xnxxh.relay-meter}"
DIST_DIR="$ROOT_DIR/dist"
DMG_PATH="$DIST_DIR/Relay-Meter-v$APP_VERSION.dmg"
APPCAST_PATH="$DIST_DIR/appcast.xml"
APPCAST_WORK_DIR="$DIST_DIR/appcast-work"
RELEASE_BASE_URL="${RELEASE_BASE_URL:-https://github.com/0xnxxh/relay-meter/releases/download/v$APP_VERSION/}"

if [[ ! -f "$PRIVATE_KEY" ]]; then
  echo "missing Sparkle private key: $PRIVATE_KEY" >&2
  exit 1
fi

if [[ ! -f "$DMG_PATH" ]]; then
  "$ROOT_DIR/scripts/package_dmg.sh" >/dev/null
fi

rm -rf "$APPCAST_WORK_DIR"
mkdir -p "$APPCAST_WORK_DIR"
cp "$DMG_PATH" "$APPCAST_WORK_DIR/"

"$GENERATE_APPCAST" \
  --account "$ACCOUNT" \
  --ed-key-file "$PRIVATE_KEY" \
  --download-url-prefix "$RELEASE_BASE_URL" \
  "$APPCAST_WORK_DIR" >/dev/null

if [[ ! -f "$APPCAST_WORK_DIR/appcast.xml" ]]; then
  echo "appcast not generated at $APPCAST_WORK_DIR/appcast.xml" >&2
  exit 1
fi

cp "$APPCAST_WORK_DIR/appcast.xml" "$APPCAST_PATH"
rm -rf "$APPCAST_WORK_DIR"

echo "$APPCAST_PATH"
