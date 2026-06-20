#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SPARKLE_VERSION="${SPARKLE_VERSION:-2.9.3}"
VENDOR_DIR="$ROOT_DIR/Vendor/Sparkle-$SPARKLE_VERSION"
ARCHIVE="$ROOT_DIR/Vendor/Sparkle-$SPARKLE_VERSION.tar.xz"
URL="https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-$SPARKLE_VERSION.tar.xz"

if [[ -d "$VENDOR_DIR/Sparkle.framework" ]]; then
  echo "$VENDOR_DIR"
  exit 0
fi

mkdir -p "$ROOT_DIR/Vendor"
if [[ ! -f "$ARCHIVE" ]]; then
  /usr/bin/curl -L --fail --output "$ARCHIVE" "$URL"
fi

rm -rf "$VENDOR_DIR"
mkdir -p "$VENDOR_DIR"
/usr/bin/tar -xJf "$ARCHIVE" -C "$VENDOR_DIR" --strip-components 1

if [[ ! -d "$VENDOR_DIR/Sparkle.framework" ]]; then
  echo "Sparkle.framework missing after extraction" >&2
  exit 1
fi

echo "$VENDOR_DIR"
