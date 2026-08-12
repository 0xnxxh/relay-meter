import AppKit
import Foundation

@main
struct CharacterizationTests {
    @MainActor
    static func main() async {
        testMenuValueFormatter()
        testHealthColors()
        testUsageActivityDateBounds()
        testActivityDisplayModes()
        testUsageActivityAggregation()
        testUsageActivityCoverage()
        testUsageActivitySourceAggregation()
        testUsageActivityQuantileIntensity()
        testNewAPIActivityRowDecoding()
        await testNewAPIActivityUsesAggregateEndpoint()
        testActivityMenuLayout()
        testActivityWindowLayout()
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

    private static func testActivityDisplayModes() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let reference = date("2026-08-12T15:30:00Z")
        let bounds = AppConfig.defaultConfig.activityBounds(reference: reference, calendar: calendar)
        expect(bounds?.start == date("2025-08-12T00:00:00Z"), "activity fetch must cover the rolling year")
        expect(bounds?.end == reference, "activity fetch must end at the reference time")
        let dataset = UsageActivitySeries.dataset(points: [], bounds: bounds!, knownBounds: [bounds!], calendar: calendar)
        let calendarYear = UsageActivityDisplayMode.calendarYear.dataset(from: dataset, calendar: calendar)
        let rollingYear = UsageActivityDisplayMode.rollingYear.dataset(from: dataset, calendar: calendar)
        expect(calendarYear.days.first?.start == date("2026-01-01T00:00:00Z"), "calendar-year display must start on January 1")
        expect(rollingYear.days.first?.start == date("2025-08-12T00:00:00Z"), "rolling-year display must retain the trailing year")
    }

    private static func testUsageActivityCoverage() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let bounds = UsageDateBounds(
            start: date("2026-07-01T00:00:00Z"),
            end: date("2026-07-03T23:59:59Z")
        )
        let points = [
            UsageTrendPoint(
                bucketStartMs: milliseconds("2026-07-01T12:00:00Z"),
                label: "",
                requests: 3,
                failures: 0,
                tokens: 120
            )
        ]
        let dataset = UsageActivitySeries.dataset(
            points: points,
            bounds: bounds,
            knownBounds: [UsageDateBounds(
                start: date("2026-07-01T00:00:00Z"),
                end: date("2026-07-02T23:59:59Z")
            )],
            calendar: calendar
        )

        expect(dataset.availability == .partial, "activity with an uncovered day must be partial")
        expect(dataset.days.map(\.state) == [.observed, .knownZero, .unknown], "missing and uncovered activity days must remain distinct")
    }

    private static func testUsageActivitySourceAggregation() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let bounds = UsageDateBounds(
            start: date("2026-07-01T00:00:00Z"),
            end: date("2026-07-02T23:59:59Z")
        )
        let first = UsageActivitySeries.dataset(
            points: [UsageTrendPoint(bucketStartMs: milliseconds("2026-07-01T12:00:00Z"), label: "", requests: 2, failures: 0, tokens: 80)],
            bounds: bounds,
            knownBounds: [bounds],
            calendar: calendar
        )
        let second = UsageActivitySeries.dataset(
            points: [UsageTrendPoint(bucketStartMs: milliseconds("2026-07-02T12:00:00Z"), label: "", requests: 4, failures: 0, tokens: 160)],
            bounds: bounds,
            knownBounds: [UsageDateBounds(start: date("2026-07-02T00:00:00Z"), end: bounds.end)],
            calendar: calendar
        )
        let aggregate = UsageActivitySeries.aggregateSources(
            [first, second],
            expectedSourceCount: 2,
            calendar: calendar
        )

        expect(aggregate.days[0].requests == 2 && aggregate.days[0].state == .partial, "an uncovered source must make the aggregate day partial")
        expect(aggregate.days[1].requests == 4 && aggregate.days[1].state == .observed, "fully covered aggregate days must remain observed")
    }

    private static func testUsageActivityQuantileIntensity() {
        let values = [1, 2, 3, 100]
        expect(UsageActivitySeries.intensity(value: 1, distribution: values) == 1, "lowest non-zero activity should use level one")
        expect(UsageActivitySeries.intensity(value: 3, distribution: values) == 3, "a single outlier must not compress ordinary activity into level one")
        expect(UsageActivitySeries.intensity(value: 100, distribution: values) == 4, "highest activity should use level four")
    }

    private static func testNewAPIActivityRowDecoding() {
        let json = #"{"created_at":1782864000,"count":7,"token_used":321}"#.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let row = try! decoder.decode(NewAPIActivityRow.self, from: json)
        expect(row.createdAt == 1_782_864_000, "new-api activity timestamp decoding changed")
        expect(row.count == 7 && row.tokenUsed == 321, "new-api activity values must decode from the aggregate endpoint")
    }

    private static func testNewAPIActivityUsesAggregateEndpoint() async {
        RequestStubURLProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RequestStubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        var config = AppConfig.defaultConfig
        let adapter = AdapterConfig(
            id: "new-api-test",
            name: "new-api Test",
            enabled: true,
            platform: .newApi,
            baseURL: "https://new-api.test",
            managementKey: "test-token",
            authHeaderName: "Authorization",
            newApiUserID: 1,
            monitoringPath: "/"
        )
        config.adapters = [adapter]
        config.platform = .newApi
        config.baseURL = adapter.baseURL
        config.managementKey = adapter.managementKey
        config.newApiUserID = adapter.newApiUserID

        let snapshot = try! await UsageClient(config: config, session: session).fetchSnapshot()
        let requests = RequestStubURLProtocol.recordedRequests()
        expect(requests.contains { $0.url?.path == "/api/status" }, "new-api activity must check data export status")
        expect(requests.contains { $0.url?.path == "/api/data/" || $0.url?.path == "/api/data" }, "new-api activity must use the aggregate data endpoint")
        let logRequests = requests.filter { $0.url?.path == "/api/log/" || $0.url?.path == "/api/log" }
        expect(logRequests.count == 2, "new-api activity must not add a raw-log request")
        expect(logRequests.allSatisfy { $0.url?.query?.contains("page_size=100") == true }, "new-api log requests must honor the upstream page limit")
        expect(snapshot.activity.days.contains { $0.state == .observed }, "new-api aggregate rows must populate the activity dataset")
    }

    @MainActor
    private static func testActivityMenuLayout() {
        let dataset = previewActivityDataset()
        let card = ActivityMenuCardView(
            dataset: dataset,
            texts: TextBundle.forLanguage(.english),
            onOpenDetails: {}
        )
        card.setFrameSize(card.fittingSize)
        card.layoutSubtreeIfNeeded()
        expect(ActivityHeatmapView.compactColumnCount == 13, "compact activity heatmap must use thirteen week columns")
        expect(ActivityHeatmapView.compactRowCount == 7, "compact activity heatmap must use seven weekday rows")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let reference = date("2026-08-12T12:00:00Z")
        let monday = ActivityHeatmapView.compactGridPosition(
            for: date("2026-08-10T12:00:00Z"),
            reference: reference,
            calendar: calendar
        )
        let wednesday = ActivityHeatmapView.compactGridPosition(
            for: reference,
            reference: reference,
            calendar: calendar
        )
        expect(monday?.column == 12 && monday?.row == 0, "compact activity weeks must run left to right")
        expect(wednesday?.column == 12 && wednesday?.row == 2, "compact activity weekdays must run Monday to Sunday")
        if let previewPath = ProcessInfo.processInfo.environment["RELAY_METER_ACTIVITY_CARD_PREVIEW_PATH"] {
            render(card, to: previewPath)
        }
    }

    @MainActor
    private static func testActivityWindowLayout() {
        let dataset = previewActivityDataset()
        let snapshot = UsageSnapshot(
            sourceID: "preview",
            sourceName: "Preview",
            platform: .cliproxyapiPro,
            selectedRange: .thirtyDays,
            scope: UsageScope(),
            recent: UsageScope(),
            trendPoints: [],
            activity: dataset,
            topModels: [],
            topApiKeys: [],
            refreshedAt: Date()
        )
        let dashboard = UsageDashboardSnapshot(
            selectedRange: .thirtyDays,
            aggregate: snapshot,
            adapters: [snapshot],
            errors: [],
            refreshedAt: Date()
        )
        let controller = ActivityWindowController(
            dashboard: dashboard,
            selectedSourceID: UsageDashboardSnapshot.aggregateSourceID,
            texts: TextBundle.forLanguage(.english)
        )
        guard let contentView = controller.window?.contentView else {
            fatalError("activity window content view missing")
        }
        contentView.layoutSubtreeIfNeeded()
        expect(controller.window?.frame.width == 820, "activity window width changed")
        expect(controller.window?.titleVisibility == .hidden, "activity window system title must be hidden")
        expect(controller.window?.titlebarAppearsTransparent == true, "activity window title bar must blend into the content")
        expect(controller.window?.styleMask.contains(.fullSizeContentView) == true, "activity window content must extend through the title bar")
        expect(contentView.fittingSize.height <= 300, "activity window content must fit without clipping")
        expect(findButton(in: contentView, titled: "REQUESTS") != nil, "activity requests metric control missing")
        expect(findButton(in: contentView, titled: "TOKENS") != nil, "activity tokens metric control missing")
        expect(findButton(in: contentView, titled: "CALENDAR YEAR") != nil, "calendar-year activity control missing")
        expect(findButton(in: contentView, titled: "ROLLING YEAR") != nil, "rolling-year activity control missing")
        expect(findView(in: contentView) { $0 is PixelPopupButton } != nil, "activity source control must use the RelayTheme popup")
        expect(findView(in: contentView) { $0 is NSPopUpButton } == nil, "activity source control must not use the system popup")
        if let previewPath = ProcessInfo.processInfo.environment["RELAY_METER_ACTIVITY_PREVIEW_PATH"] {
            render(contentView, to: previewPath)
        }
    }

    private static func previewActivityDataset() -> UsageActivityDataset {
        let bounds = UsageDateBounds(
            start: date("2026-01-01T00:00:00Z"),
            end: date("2026-08-12T23:59:59Z")
        )
        return UsageActivitySeries.dataset(
            points: [
                UsageTrendPoint(bucketStartMs: milliseconds("2026-08-11T12:00:00Z"), label: "", requests: 7, failures: 0, tokens: 420),
                UsageTrendPoint(bucketStartMs: milliseconds("2026-08-12T12:00:00Z"), label: "", requests: 12, failures: 1, tokens: 960)
            ],
            bounds: bounds,
            knownBounds: [bounds]
        )
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

    @MainActor
    private static func findView(in view: NSView, matching predicate: (NSView) -> Bool) -> NSView? {
        if predicate(view) { return view }
        for subview in view.subviews {
            if let match = findView(in: subview, matching: predicate) {
                return match
            }
        }
        return nil
    }

    @MainActor
    private static func render(_ view: NSView, to path: String) {
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            fatalError("activity preview bitmap unavailable")
        }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            fatalError("activity preview PNG encoding failed")
        }
        try! data.write(to: URL(fileURLWithPath: path))
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

private final class RequestStubURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var requests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self.requests.append(request)
        Self.lock.unlock()
        let path = request.url?.path ?? ""
        let body: String
        switch path {
        case "/api/status":
            body = #"{"success":true,"message":"","data":{"enable_data_export":true}}"#
        case "/api/data/", "/api/data":
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
            let timestamp = components?.queryItems?.first { $0.name == "start_timestamp" }?.value ?? "0"
            body = #"{"success":true,"message":"","data":[{"created_at":\#(timestamp),"count":2,"token_used":40}]}"#
        case "/api/log/", "/api/log":
            body = #"{"success":true,"message":"","data":{"items":[]}}"#
        default:
            body = #"{"success":false,"message":"unexpected path","data":{}}"#
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    static func reset() {
        lock.lock()
        requests = []
        lock.unlock()
    }

    static func recordedRequests() -> [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return requests
    }
}
