#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SVG="$ROOT_DIR/Resources/Logo/relay-meter-logo.svg"
ICONSET="$ROOT_DIR/.build/icon/AppIcon.iconset"
ICNS="$ROOT_DIR/Resources/AppIcon.icns"

if [[ ! -f "$SVG" ]]; then
  echo "missing logo source: $SVG" >&2
  exit 1
fi

command -v sips >/dev/null
command -v iconutil >/dev/null

rm -rf "$ICONSET"
mkdir -p "$ICONSET" "$(dirname "$ICNS")"

make_png() {
  local points="$1"
  local scale="$2"
  local suffix="$3"
  local pixels=$((points * scale))
  local out="$ICONSET/icon_${points}x${points}${suffix}.png"
  sips -s format png -z "$pixels" "$pixels" "$SVG" --out "$out" >/dev/null
}

if ! make_png 16 1 "" 2>/dev/null; then
  if [[ -f "$ICNS" ]]; then
    echo "$ICNS"
    exit 0
  fi
  echo "failed to render $SVG and no existing icon is available" >&2
  exit 1
fi
make_png 16 2 "@2x"
make_png 32 1 ""
make_png 32 2 "@2x"
make_png 128 1 ""
make_png 128 2 "@2x"
make_png 256 1 ""
make_png 256 2 "@2x"
make_png 512 1 ""
make_png 512 2 "@2x"

iconutil -c icns "$ICONSET" -o "$ICNS"
echo "$ICNS"
