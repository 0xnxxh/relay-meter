#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SPARKLE_DIR="$("$ROOT_DIR/scripts/ensure_sparkle.sh")"
GENERATE_KEYS="$SPARKLE_DIR/bin/generate_keys"
KEY_FILE="$ROOT_DIR/sparkle_private_key"
PUBLIC_KEY_FILE="$ROOT_DIR/sparkle_public_ed_key.txt"
ACCOUNT="${SPARKLE_KEY_ACCOUNT:-0xnxxh.cpa-menubar}"

if [[ -e "$KEY_FILE" ]]; then
  echo "refusing to overwrite $KEY_FILE" >&2
  exit 1
fi

umask 077
"$GENERATE_KEYS" --account "$ACCOUNT" >"$PUBLIC_KEY_FILE.tmp"
"$GENERATE_KEYS" --account "$ACCOUNT" -x "$KEY_FILE" >/dev/null
awk -F'[<>]' '/SUPublicEDKey/ { getline; print $3 }' "$PUBLIC_KEY_FILE.tmp" >"$PUBLIC_KEY_FILE"
rm -f "$PUBLIC_KEY_FILE.tmp"

if [[ ! -s "$PUBLIC_KEY_FILE" ]]; then
  echo "failed to extract Sparkle public key" >&2
  exit 1
fi

echo "private_key=$KEY_FILE"
echo "public_key=$PUBLIC_KEY_FILE"
