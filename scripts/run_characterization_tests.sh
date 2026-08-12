#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_BINARY="$ROOT_DIR/.build/characterization-tests"

mkdir -p "$ROOT_DIR/.build"
swiftc \
  -parse-as-library \
  -framework AppKit \
  "$ROOT_DIR/Sources/RelayMeter/Models.swift" \
  "$ROOT_DIR/Sources/RelayMeter/UsageActivity.swift" \
  "$ROOT_DIR/Sources/RelayMeter/AppLogger.swift" \
  "$ROOT_DIR/Sources/RelayMeter/UsageClient.swift" \
  "$ROOT_DIR/Sources/RelayMeter/Localization.swift" \
  "$ROOT_DIR/Sources/RelayMeter/RelayTheme.swift" \
  "$ROOT_DIR/Sources/RelayMeter/MenuCardComponents.swift" \
  "$ROOT_DIR/Sources/RelayMeter/ActivityMenuCardView.swift" \
  "$ROOT_DIR/Sources/RelayMeter/ActivityWindow.swift" \
  "$ROOT_DIR/Sources/RelayMeter/SettingsWindow.swift" \
  "$ROOT_DIR/Tests/CharacterizationTests.swift" \
  -o "$TEST_BINARY"

"$TEST_BINARY"
