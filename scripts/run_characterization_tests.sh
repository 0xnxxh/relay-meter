#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_BINARY="$ROOT_DIR/.build/characterization-tests"

# Compile every app source except main.swift, whose top-level code and Sparkle
# dependency cannot link into the test harness. Globbing keeps new files covered.
SOURCES=()
while IFS= read -r file; do
  SOURCES+=("$file")
done < <(find "$ROOT_DIR/Sources/RelayMeter" -name '*.swift' ! -name 'main.swift' | sort)

mkdir -p "$ROOT_DIR/.build"
swiftc \
  -parse-as-library \
  -framework AppKit \
  "${SOURCES[@]}" \
  "$ROOT_DIR/Tests/CharacterizationTests.swift" \
  -o "$TEST_BINARY"

"$TEST_BINARY"
