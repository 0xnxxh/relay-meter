#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="CPA Menubar"
PROCESS_NAME="CPA Menubar"
PRODUCT_NAME="cpa-menubar"
BUNDLE_ID="com.hoon.cpa-menubar"
MIN_SYSTEM_VERSION="13.0"
FEED_URL="https://github.com/0xnxxh/cpa-menubar/releases/latest/download/appcast.xml"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/version.sh"
SPARKLE_DIR="$("$ROOT_DIR/scripts/ensure_sparkle.sh")"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_FRAMEWORKS="$APP_CONTENTS/Frameworks"
APP_BINARY="$APP_MACOS/$PROCESS_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ICON_FILE="$ROOT_DIR/Resources/AppIcon.icns"
RELEASE_DIR="$ROOT_DIR/.build/release"
RELEASE_BINARY="$RELEASE_DIR/$PRODUCT_NAME"
SPARKLE_PUBLIC_KEY_FILE="$ROOT_DIR/sparkle_public_ed_key.txt"

usage() {
  echo "usage: $0 [run|build|--debug|--logs|--telemetry|--verify]" >&2
}

build_bundle() {
  "$ROOT_DIR/scripts/make_icon.sh" >/dev/null
  local build_binary
  build_binary="$(compile_release_binary)"
  local sparkle_public_key
  sparkle_public_key="$(read_sparkle_public_key)"

  rm -rf "$APP_BUNDLE"
  mkdir -p "$APP_MACOS" "$APP_RESOURCES" "$APP_FRAMEWORKS"
  cp "$build_binary" "$APP_BINARY"
  cp "$ICON_FILE" "$APP_RESOURCES/AppIcon.icns"
  copy_sparkle_framework
  chmod +x "$APP_BINARY"

  cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$PROCESS_NAME</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>SUEnableDownloaderSystemProfiling</key>
  <false/>
  <key>SUFeedURL</key>
  <string>$FEED_URL</string>
  <key>SUPublicEDKey</key>
  <string>$sparkle_public_key</string>
</dict>
</plist>
PLIST

  /usr/bin/plutil -lint "$INFO_PLIST" >/dev/null
  sign_bundle

  echo "$APP_BUNDLE"
}

compile_release_binary() {
  mkdir -p "$RELEASE_DIR"
  swiftc \
    -O \
    -framework AppKit \
    -F "$SPARKLE_DIR" \
    -framework Sparkle \
    -Xlinker -rpath \
    -Xlinker "@executable_path/../Frameworks" \
    "$ROOT_DIR/Sources/CPAMenubar/AppLogger.swift" \
    "$ROOT_DIR/Sources/CPAMenubar/Models.swift" \
    "$ROOT_DIR/Sources/CPAMenubar/Localization.swift" \
    "$ROOT_DIR/Sources/CPAMenubar/ConfigStore.swift" \
    "$ROOT_DIR/Sources/CPAMenubar/DebugSummary.swift" \
    "$ROOT_DIR/Sources/CPAMenubar/UsageClient.swift" \
    "$ROOT_DIR/Sources/CPAMenubar/MenuCardComponents.swift" \
    "$ROOT_DIR/Sources/CPAMenubar/RankingMenuCardView.swift" \
    "$ROOT_DIR/Sources/CPAMenubar/TrendMenuCardView.swift" \
    "$ROOT_DIR/Sources/CPAMenubar/SnapshotMenuView.swift" \
    "$ROOT_DIR/Sources/CPAMenubar/SettingsWindow.swift" \
    "$ROOT_DIR/Sources/CPAMenubar/main.swift" \
    "$ROOT_DIR/Sources/CPAMenubar/MenuDelegate.swift" \
    -o "$RELEASE_BINARY"
  echo "$RELEASE_BINARY"
}

read_sparkle_public_key() {
  if [[ ! -s "$SPARKLE_PUBLIC_KEY_FILE" ]]; then
    echo "missing Sparkle public key; run scripts/generate_sparkle_keys.sh" >&2
    exit 1
  fi
  tr -d '[:space:]' <"$SPARKLE_PUBLIC_KEY_FILE"
}

copy_sparkle_framework() {
  if [[ ! -d "$SPARKLE_DIR/Sparkle.framework" ]]; then
    echo "Sparkle.framework not found after build" >&2
    exit 1
  fi
  cp -R "$SPARKLE_DIR/Sparkle.framework" "$APP_FRAMEWORKS/"
}

sign_bundle() {
  if [[ -d "$APP_FRAMEWORKS/Sparkle.framework" ]]; then
    /usr/bin/codesign --force --sign - "$APP_FRAMEWORKS/Sparkle.framework" >/dev/null
  fi
  /usr/bin/codesign --force --sign - "$APP_BUNDLE" >/dev/null
}

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

pkill -x "$PROCESS_NAME" >/dev/null 2>&1 || true
build_bundle >/dev/null

case "$MODE" in
  run)
    open_app
    ;;
  build)
    echo "$APP_BUNDLE"
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$PROCESS_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$PROCESS_NAME" >/dev/null
    ;;
  *)
    usage
    exit 2
    ;;
esac
