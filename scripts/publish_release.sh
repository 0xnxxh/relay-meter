#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/version.sh"

TAG="v$APP_VERSION"
DMG_PATH="$ROOT_DIR/dist/Relay-Meter-v$APP_VERSION.dmg"
APPCAST_PATH="$ROOT_DIR/dist/appcast.xml"
RELEASE_NOTES_PATH="$ROOT_DIR/RELEASE_NOTES.md"

if [[ "${CONFIRM_PUBLISH:-}" != "1" ]]; then
  echo "refusing to publish without CONFIRM_PUBLISH=1" >&2
  exit 2
fi

if [[ ! -s "$RELEASE_NOTES_PATH" ]]; then
  echo "missing release notes: $RELEASE_NOTES_PATH" >&2
  exit 1
fi

if ! head -n 1 "$RELEASE_NOTES_PATH" | grep -qx "# Relay Meter $TAG"; then
  echo "release notes must start with: # Relay Meter $TAG" >&2
  exit 1
fi

"$ROOT_DIR/scripts/release_check.sh" >/dev/null

if [[ "$(git -C "$ROOT_DIR" status --short)" != "" ]]; then
  echo "working tree is not clean; commit before publishing" >&2
  exit 1
fi

if ! git -C "$ROOT_DIR" rev-parse "$TAG" >/dev/null 2>&1; then
  git -C "$ROOT_DIR" tag -a "$TAG" -m "Relay Meter $APP_VERSION"
fi

gh release create "$TAG" \
  "$DMG_PATH" \
  "$APPCAST_PATH" \
  --repo 0xnxxh/relay-meter \
  --title "Relay Meter $APP_VERSION" \
  --notes-file "$RELEASE_NOTES_PATH"
