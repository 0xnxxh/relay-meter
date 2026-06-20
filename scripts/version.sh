#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

read_value() {
  local file="$1"
  tr -d '[:space:]' <"$ROOT_DIR/$file"
}

APP_VERSION="${APP_VERSION:-$(read_value VERSION)}"
BUILD_NUMBER="${BUILD_NUMBER:-$(read_value BUILD_NUMBER)}"

if [[ ! "$APP_VERSION" =~ ^[0-9]+(\.[0-9]+){1,2}([-+][0-9A-Za-z.-]+)?$ ]]; then
  echo "invalid APP_VERSION: $APP_VERSION" >&2
  exit 2
fi

if [[ ! "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "invalid BUILD_NUMBER: $BUILD_NUMBER" >&2
  exit 2
fi

export APP_VERSION
export BUILD_NUMBER
