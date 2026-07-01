# AGENTS.md
|IMPORTANT:先读取本仓库文件、脚本输出和当前 Git 状态；不要依赖历史对话或记忆判断架构、命令、版本、发布状态。
|Project:SwiftPM macOS menu bar app|product `relay-meter`|bundle app `Relay Meter.app`|minimum macOS `13.0`
|Language:用户可读输出默认简体中文|代码标识符/命令/路径保持英文|发布说明按仓库现有双语/英文风格保持简洁
|Entry:`Sources/RelayMeter/main.swift` owns `MenuBarApp`, status item, main `NSPanel`, Settings window, Sparkle updater wiring
|Theme:`Sources/RelayMeter/RelayTheme.swift` centralizes Candlebar-style pixel colors, fonts, buttons, fields, background; UI color/font changes should reuse it first
|Views:`SnapshotMenuView.swift` menu body/tabs/cards/footer|`MenuCardComponents.swift` shared card/value widgets|`RankingMenuCardView.swift` rankings|`TrendMenuCardView.swift` chart
|Settings:`Sources/RelayMeter/SettingsWindow.swift` contains custom `PixelPopupButton`, `PixelTextField`, `PixelSecureField`; preserve editable/selectable behavior and outside-click popup dismissal
|Models:`Sources/RelayMeter/Models.swift` defines config, adapters, languages, ranges, display items, snapshots, errors
|Config:`ConfigStore.swift` reads/writes `~/.config/relay-meter/config.json`; config includes access keys, so never log or hard-code secrets
|Clients:`UsageClient.swift` implements platform-specific relay API adapters; do not replace adapter-specific routes with generic URL string rewrites
|Localization:`Localization.swift` owns English and Simplified Chinese UI strings; add both languages for user-facing copy
|Logs:`AppLogger.swift` writes to `~/Library/Logs/relay-meter/relay-meter.log`; logs must not include management keys
|Build:`scripts/build_and_run.sh build` compiles release binary, bundles Sparkle, writes Info.plist from `VERSION` and `BUILD_NUMBER`, ad-hoc signs app
|Verify:`scripts/build_and_run.sh --verify` launches bundled app and checks process starts|`git diff --check` before commit
|ReleaseCheck:`scripts/release_check.sh` builds app, creates DMG, generates Sparkle appcast, verifies plist/codesign/dmg/appcast URLs
|Version:`VERSION` is app version|`BUILD_NUMBER` is numeric CFBundleVersion|patch releases normally increment both
|Sparkle:`scripts/generate_appcast.sh` needs `sparkle_private_key` or `SPARKLE_PRIVATE_KEY`; `sparkle_private_key` is ignored and must never be committed
|Distribution:`dist/` is ignored; release assets are `dist/Relay-Meter-v$VERSION.dmg` and `dist/appcast.xml`
|Publish:`CONFIRM_PUBLISH=1 scripts/publish_release.sh` requires a clean worktree, runs release check, creates tag `v$VERSION`, and publishes via `gh release create`
|ReleaseNotes:`RELEASE_NOTES.md` must start with `# Relay Meter v$VERSION`; update it before publishing
|Git:Use explicit `git add` paths; do not stage `.build/`, `dist/`, `Vendor/`, `.codex/`, `sparkle_private_key`, or local screenshots
|Scope:Keep UI changes in AppKit views/components; avoid unrelated refactors or new dependencies unless the release task requires them
