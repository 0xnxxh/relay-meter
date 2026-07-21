import AppKit
import Foundation

@main
struct CharacterizationTests {
    @MainActor
    static func main() {
        testMenuValueFormatter()
        testHealthColors()
        testUsageActivityDateBounds()
        testUsageActivityAggregation()
        testEnglishSettingsCopy()
        testChineseSettingsCopy()
        print("Characterization tests passed")
    }

    private static func testMenuValueFormatter() {
        expect(MenuValueFormatter.percent(0.994) == "99%", "percent rounding changed")
        expect(MenuValueFormatter.compact(999) == "999", "compact units changed below 1K")
        expect(MenuValueFormatter.compact(1_500) == "1.5K", "compact K formatting changed")
        expect(MenuValueFormatter.compact(2_500_000) == "2.5M", "compact M formatting changed")
        expect(MenuValueFormatter.duration(ms: 999) == "999 ms", "millisecond formatting changed")
        expect(MenuValueFormatter.duration(ms: 1_500) == "1.5 s", "second formatting changed")
        expect(MenuValueFormatter.duration(ms: 90_000) == "1.5 min", "minute formatting changed")
        expect(MenuValueFormatter.duration(ms: 5_400_000) == "1.5 h", "hour formatting changed")
    }

    private static func testHealthColors() {
        expect(RelayTheme.healthColor(.good).isEqual(RelayTheme.up), "good health color changed")
        expect(RelayTheme.healthColor(.idle).isEqual(RelayTheme.muted), "idle health color changed")
        expect(RelayTheme.healthColor(.warn).isEqual(RelayTheme.warn), "warning health color changed")
        expect(RelayTheme.healthColor(.bad).isEqual(RelayTheme.down), "bad health color changed")
    }

    private static func testUsageActivityDateBounds() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let reference = date("2026-07-21T15:30:00Z")

        expect(
            UsageActivityPeriod.thisWeek.bounds(reference: reference, calendar: calendar) == UsageDateBounds(
                start: date("2026-07-20T00:00:00Z"),
                end: reference
            ),
            "this-week activity bounds changed"
        )
        expect(
            UsageActivityPeriod.thisMonth.bounds(reference: reference, calendar: calendar) == UsageDateBounds(
                start: date("2026-07-01T00:00:00Z"),
                end: reference
            ),
            "this-month activity bounds changed"
        )
        expect(
            UsageActivityPeriod.thisYear.bounds(reference: reference, calendar: calendar) == UsageDateBounds(
                start: date("2026-01-01T00:00:00Z"),
                end: reference
            ),
            "this-year activity bounds changed"
        )
        expect(
            UsageActivityPeriod.last7Days.bounds(reference: reference, calendar: calendar) == UsageDateBounds(
                start: date("2026-07-15T00:00:00Z"),
                end: reference
            ),
            "rolling seven-day activity bounds changed"
        )
        expect(
            UsageActivityPeriod.custom.bounds(
                reference: reference,
                calendar: calendar,
                customStart: date("2026-02-03T18:00:00Z"),
                customEnd: date("2026-02-05T09:00:00Z")
            ) == UsageDateBounds(
                start: date("2026-02-03T00:00:00Z"),
                end: date("2026-02-05T23:59:59Z")
            ),
            "custom activity bounds must include the full end day"
        )
    }

    private static func testUsageActivityAggregation() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let points = [
            UsageTrendPoint(bucketStartMs: milliseconds("2026-07-01T10:00:00Z"), label: "", requests: 2, failures: 0, tokens: 100),
            UsageTrendPoint(bucketStartMs: milliseconds("2026-07-01T18:00:00Z"), label: "", requests: 3, failures: 1, tokens: 250),
            UsageTrendPoint(bucketStartMs: milliseconds("2026-07-08T12:00:00Z"), label: "", requests: 4, failures: 0, tokens: 50)
        ]

        let daily = UsageActivitySeries.aggregate(points, granularity: .daily, calendar: calendar)
        expect(daily.count == 2, "daily activity should merge points on the same day")
        expect(daily[0].requests == 5 && daily[0].tokens == 350, "daily activity totals changed")

        let weekly = UsageActivitySeries.aggregate(points, granularity: .weekly, calendar: calendar)
        expect(weekly.count == 2, "weekly activity should use calendar weeks")
        expect(weekly[0].requests == 5 && weekly[1].requests == 4, "weekly activity totals changed")

        let monthly = UsageActivitySeries.aggregate(points, granularity: .monthly, calendar: calendar)
        expect(monthly.count == 1 && monthly[0].tokens == 400, "monthly activity totals changed")

        let cumulative = UsageActivitySeries.aggregate(points, granularity: .cumulative, calendar: calendar)
        expect(cumulative.map(\.tokens) == [350, 400], "cumulative activity must use daily running totals")
        expect(UsageActivitySeries.intensity(value: 0, maximum: 400) == 0, "zero usage must use the empty color")
        expect(UsageActivitySeries.intensity(value: 400, maximum: 400) == 4, "maximum usage must use the darkest color")
    }

    private static func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    private static func milliseconds(_ value: String) -> Int {
        Int(date(value).timeIntervalSince1970 * 1_000)
    }

    @MainActor
    private static func testEnglishSettingsCopy() {
        let copy = settingsCopy(language: .english)
        expectCopy([
            "Relay Meter Settings", "Settings", "Configure adapters, menu bar display, and monitoring cards.",
            "ADAPTERS", "Name", "Base URL", "Access Key", "new-api User ID", "Refresh Interval (seconds)",
            "DISPLAY", "Language", "Menu Bar Title", "Range", "CARDS",
            "English", "Requests + success rate", "Total tokens", "Failures", "Success rate",
            "Average latency", "Cache tokens", "Last 15m activity", "Today", "7d", "30d", "All",
            "Traffic", "Tokens", "Cache", "Latency", "Last 15m", "Trend chart", "Top model", "Top API key", "Last updated",
            "Enabled", "SHOW", "HIDE", "DELETE", "ADD ADAPTER",
            "Enabled adapters refresh in parallel; one failed adapter does not block the others.",
            "CHECK FOR UPDATES...", "CANCEL", "SAVE"
        ], in: copy, language: "English")
    }

    @MainActor
    private static func testChineseSettingsCopy() {
        let copy = settingsCopy(language: .chinese)
        expectCopy([
            "Relay Meter 设置", "设置", "分别配置 adapter、菜单栏显示和监控卡片。",
            "ADAPTERS", "名称", "服务地址", "访问密钥", "new-api 用户 ID", "刷新间隔（秒）",
            "显示", "语言", "菜单栏默认显示", "时间范围", "卡片",
            "简体中文", "请求数 + 成功率", "总 Token", "失败数", "成功率",
            "平均延迟", "缓存 Token", "最近 15 分钟活跃", "今天", "7 天", "30 天", "全部",
            "流量", "Token", "缓存", "延迟", "最近 15 分钟", "趋势曲线图", "Top 模型", "Top API Key", "最后更新时间",
            "启用", "显示", "隐藏", "删除", "添加 ADAPTER",
            "启用的 adapter 会并发刷新；单个 adapter 失败不会阻止其他 adapter 展示。",
            "检查更新...", "取消", "保存"
        ], in: copy, language: "Chinese")
    }

    @MainActor
    private static func settingsCopy(language: AppLanguage) -> Set<String> {
        var copy = Set<String>()
        for metric in DisplayMetric.allCases {
            for range in UsageTimeRange.allCases {
                var config = AppConfig.defaultConfig
                config.language = language
                config.titleMetric = metric
                config.timeRange = range
                let controller = SettingsWindowController(config: config, onSave: { _ in }, onCheckForUpdates: {})
                if let title = controller.window?.title {
                    copy.insert(title)
                }
                if let contentView = controller.window?.contentView {
                    collectCopy(from: contentView, into: &copy)
                    if let showKeyButton = findButton(
                        in: contentView,
                        titled: language == .chinese ? "显示" : "SHOW"
                    ) {
                        showKeyButton.performClick(nil)
                        collectCopy(from: contentView, into: &copy)
                    }
                }
            }
        }
        return copy
    }

    @MainActor
    private static func collectCopy(from view: NSView, into copy: inout Set<String>) {
        if let field = view as? NSTextField {
            copy.insert(field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if let button = view as? NSButton {
            copy.insert(button.title.trimmingCharacters(in: .whitespacesAndNewlines))
            copy.insert(button.attributedTitle.string.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        for subview in view.subviews {
            collectCopy(from: subview, into: &copy)
        }
    }

    @MainActor
    private static func findButton(in view: NSView, titled title: String) -> NSButton? {
        if let button = view as? NSButton,
           button.attributedTitle.string.trimmingCharacters(in: .whitespacesAndNewlines) == title {
            return button
        }
        for subview in view.subviews {
            if let button = findButton(in: subview, titled: title) {
                return button
            }
        }
        return nil
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fatalError(message)
        }
    }

    private static func expectCopy(_ expected: [String], in actual: Set<String>, language: String) {
        for value in expected {
            expect(actual.contains(value), "\(language) settings copy changed: \(value)")
        }
    }
}
