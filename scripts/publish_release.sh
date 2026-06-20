#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/version.sh"

TAG="v$APP_VERSION"
DMG_PATH="$ROOT_DIR/dist/CPA-Menubar-v$APP_VERSION.dmg"
APPCAST_PATH="$ROOT_DIR/dist/appcast.xml"

if [[ "${CONFIRM_PUBLISH:-}" != "1" ]]; then
  echo "refusing to publish without CONFIRM_PUBLISH=1" >&2
  exit 2
fi

"$ROOT_DIR/scripts/release_check.sh" >/dev/null

if [[ "$(git -C "$ROOT_DIR" status --short)" != "" ]]; then
  echo "working tree is not clean; commit before publishing" >&2
  exit 1
fi

if ! git -C "$ROOT_DIR" rev-parse "$TAG" >/dev/null 2>&1; then
  git -C "$ROOT_DIR" tag -a "$TAG" -m "CPA Menubar $APP_VERSION"
fi

gh release create "$TAG" \
  "$DMG_PATH" \
  "$APPCAST_PATH" \
  --repo 0xnxxh/cpa-menubar \
  --title "CPA Menubar $APP_VERSION" \
  --notes "CPA Menubar $APP_VERSION"
