import AppKit
import Foundation

@main
struct CharacterizationTests {
    @MainActor
    static func main() async {
        testMenuValueFormatter()
        testTokenCountFormatter()
        testUsageCostAggregation()
        testHealthColors()
        testUsageActivityDateBounds()
        testActivityDisplayModes()
        testUsageActivityAggregation()
        testUsageActivityCoverage()
        testUsageActivitySourceAggregation()
        testUsageActivityQuantileIntensity()
        testNewAPIActivityRowDecoding()
        await testCLIProxyCost()
        await testSub2APICost()
        await testNewAPIActivityUsesAggregateEndpoint()
        await testSingleAdapterDashboardRankingLabels()
        testActivityMenuLayout()
        testCostMenuLayout()
        testTopModelRankingCardLayout()
        testActivityWindowLayout()
        testEnglishSettingsCopy()
        testChineseSettingsCopy()
        testLaunchAtLoginSetting()
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
        expect(MenuValueFormatter.currencyUSD(12.345) == "$12.35", "USD cost formatting changed")
        expect(MenuValueFormatter.currencyUSD(0.0004) == "$0.0004", "small USD costs must remain visible")
    }

    private static func testTokenCountFormatter() {
        expect(MenuValueFormatter.tokenCount(0) == "0K", "zero tokens must use K")
        expect(MenuValueFormatter.tokenCount(600) == "0.6K", "sub-million tokens must use K")
        expect(MenuValueFormatter.tokenCount(505_016) == "505K", "token values must drop insignificant trailing zeroes")
        expect(MenuValueFormatter.tokenCount(505_221) == "505.2K", "K values must keep at most four significant digits")
        expect(MenuValueFormatter.tokenCount(999_999) == "999.9K", "K values must truncate to four significant digits")
        expect(MenuValueFormatter.tokenCount(1_000_000) == "1M", "one million tokens must switch to M")
        expect(MenuValueFormatter.tokenCount(1_234_567) == "1.234M", "single-digit M values must keep three decimals")
        expect(MenuValueFormatter.tokenCount(12_345_678) == "12.34M", "double-digit M values must keep two decimals")
        expect(MenuValueFormatter.tokenCount(123_456_789) == "123.4M", "triple-digit M values must keep one decimal")
        expect(MenuValueFormatter.tokenCount(999_999_999) == "999.9M", "M values must not round into B")
        expect(MenuValueFormatter.tokenCount(1_000_000_000) == "1B", "one billion tokens must switch to B")
        expect(MenuValueFormatter.tokenCount(1_234_500_000) == "1.234B", "B values must truncate to three decimals")
    }

    private static func testUsageCostAggregation() {
        expect(UsageCost.totalIfComplete([1.25, 0.75]) == 2, "complete adapter costs must aggregate")
        expect(UsageCost.totalIfComplete([1.25, nil]) == nil, "partial adapter costs must not look complete")
        expect(UsageCost.totalIfComplete([]) == nil, "an empty adapter set has no cost total")
        var pricedScope = UsageScope()
        pricedScope.costUSD = 1
        expect(UsageCost.totalIfComplete([pricedScope], expectedCount: 2) == nil, "a failed adapter must suppress the aggregate cost")
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

    private static func testCLIProxyCost() async {
        RequestStubURLProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RequestStubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        var config = AppConfig.defaultConfig
        config.baseURL = "https://cliproxy.test"
        config.adapters[0].baseURL = config.baseURL

        let snapshot = try! await UsageClient(config: config, session: session).fetchSnapshot()
        expect(snapshot.scope.costUSD == 1.25, "CLIProxy estimated cost must be exposed in USD")
    }

    private static func testSub2APICost() async {
        RequestStubURLProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RequestStubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        var config = AppConfig.defaultConfig
        let adapter = AdapterConfig(
            id: "sub2api-test",
            name: "sub2api Test",
            enabled: true,
            platform: .sub2api,
            baseURL: "https://sub2api.test",
            managementKey: "test-token",
            authHeaderName: "x-api-key",
            newApiUserID: nil,
            monitoringPath: "/admin/dashboard"
        )
        config.adapters = [adapter]
        config.platform = .sub2api
        config.baseURL = adapter.baseURL
        config.managementKey = adapter.managementKey

        let snapshot = try! await UsageClient(config: config, session: session).fetchSnapshot()
        expect(snapshot.scope.costUSD == 2, "sub2api actual cost must follow the selected trend range")
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
        expect(snapshot.scope.costUSD == 0.5, "new-api quota must use the upstream quota-per-unit conversion")
        expect(snapshot.activity.days.contains { $0.state == .observed }, "new-api aggregate rows must populate the activity dataset")
    }

    private static func testSingleAdapterDashboardRankingLabels() async {
        RequestStubURLProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RequestStubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        var config = AppConfig.defaultConfig
        let adapter = AdapterConfig(
            id: "new-api-test",
            name: "CPA",
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

        let dashboard = try! await UsageClient(config: config, session: session).fetchDashboardSnapshot()
        expect(
            dashboard.aggregate.topModels.map(\.label) == ["test-model"],
            "a single enabled adapter must not prefix top-model labels with its name"
        )
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
    private static func testCostMenuLayout() {
        var scope = UsageScope()
        scope.totalTokens = 1_234_500_000
        scope.inputTokens = 1_000_000_000
        scope.outputTokens = 234_500_000
        scope.cacheTokens = 12_345_000
        scope.costUSD = 12.345
        let snapshot = UsageSnapshot(
            sourceID: "preview",
            sourceName: "Preview",
            platform: .sub2api,
            selectedRange: .sevenDays,
            scope: scope,
            recent: UsageScope(),
            trendPoints: [],
            activity: previewActivityDataset(),
            topModels: [],
            topApiKeys: [],
            refreshedAt: Date()
        )
        var config = AppConfig.defaultConfig
        config.listItems = [.tokens]
        let view = SnapshotMenuView(snapshot: snapshot, config: config, texts: TextBundle.forLanguage(.english))
        var copy = Set<String>()
        collectCopy(from: view, into: &copy)
        expect(copy.contains("TOKENS"), "tokens card title missing")
        expect(copy.contains("1.234B"), "tokens card total must use B with truncated precision")
        expect(copy.contains("1B / 234.5M"), "input and output tokens must use the shared token formatter")
        expect(copy.contains("12.34M / 1%"), "cache tokens must use the shared token formatter")
        expect(copy.contains("$12.35"), "tokens card spend value missing")
        expect(copy.contains("ACTUAL SPEND"), "tokens card spend type missing")
        expect(!copy.contains("CURRENCY"), "tokens card must not show a currency row")
        expect(!copy.contains("RANGE"), "tokens card must not show a range row")
    }

    @MainActor
    private static func testTopModelRankingCardLayout() {
        let snapshot = UsageSnapshot(
            sourceID: "preview",
            sourceName: "Preview",
            platform: .cliproxyapiPro,
            selectedRange: .sevenDays,
            scope: UsageScope(),
            recent: UsageScope(),
            trendPoints: [],
            activity: previewActivityDataset(),
            topModels: [
                UsageRankingRow(label: "gpt-5.6-sol", requests: 3_373, failures: 0, tokens: 600_000_000),
                UsageRankingRow(label: "claude-opus-5", requests: 133, failures: 2, tokens: 300_000_000),
                UsageRankingRow(label: "claude-sonnet-5", requests: 33, failures: 2, tokens: 100_000_000)
            ],
            topApiKeys: [
                UsageRankingRow(label: "sk-must-not-render", requests: 999, failures: 0, tokens: 999)
            ],
            refreshedAt: Date()
        )
        var config = AppConfig.defaultConfig
        config.listItems = [.topModel, .topApiKey]
        expect(config.resolvedListItems == [.topModel], "legacy Top API key settings must be ignored")
        expect(!DisplayItem.defaultItems.contains(.topApiKey), "Top API key must not be enabled by default")

        let view = SnapshotMenuView(snapshot: snapshot, config: config, texts: TextBundle.forLanguage(.english))
        view.layoutSubtreeIfNeeded()
        var copy = Set<String>()
        collectCopy(from: view, into: &copy)
        expect(copy.contains("TOP MODEL"), "Top model card title missing")
        expect(copy.contains("3,373 REQ / 600M TOKEN"), "model ranking must show request and compact token counts")
        expect(!copy.contains("3,373 REQ / 100%"), "model ranking must not show success rate")
        expect(!copy.contains("TOP API KEY"), "Top API key card must be removed")
        expect(!copy.contains("sk-must-not-render"), "Top API key data must not render")

        guard let chart = findView(in: view, matching: {
            $0.identifier?.rawValue == "top-model-token-share-chart"
        }), let detail = findView(in: view, matching: {
            $0.identifier?.rawValue == "top-model-token-share-detail"
        }) as? NSTextField else {
            fatalError("Top model token-share hover UI missing")
        }
        expect(chart.bounds.width == 108 && chart.bounds.height == 108, "Top model pie chart must fit the model list without adding card whitespace")
        guard let firstRow = findView(in: view, matching: {
            $0.identifier?.rawValue == "top-model-row-1"
        }), let secondRow = findView(in: view, matching: {
            $0.identifier?.rawValue == "top-model-row-2"
        }), let thirdRow = findView(in: view, matching: {
            $0.identifier?.rawValue == "top-model-row-3"
        }) else {
            fatalError("Top model ranking rows missing")
        }
        let firstGap = firstRow.frame.minY - secondRow.frame.maxY
        let secondGap = secondRow.frame.minY - thirdRow.frame.maxY
        expect(abs(firstGap - secondGap) <= 1, "Top model rows must keep consistent vertical spacing beside the larger pie chart")
        guard let rankingColumn = firstRow.superview else {
            fatalError("Top model ranking column missing")
        }
        expect(
            chart.bounds.height <= rankingColumn.fittingSize.height,
            "Top model pie chart must not increase the ranking card content height"
        )
        if let previewPath = ProcessInfo.processInfo.environment["RELAY_METER_RANKING_CARD_PREVIEW_PATH"] {
            render(view, to: previewPath)
        }
        let hoverPoint = chart.convert(
            NSPoint(x: chart.bounds.midX, y: chart.bounds.maxY - 4),
            to: nil
        )
        guard let hoverEvent = NSEvent.mouseEvent(
            with: .mouseMoved,
            location: hoverPoint,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 0,
            pressure: 0
        ) else {
            fatalError("Top model token-share hover event unavailable")
        }
        chart.mouseMoved(with: hoverEvent)
        expect(detail.stringValue == "gpt-5.6-sol · 60%", "hovering a pie slice must show its model and share")
        expect(
            chart.accessibilityValue() as? String == "gpt-5.6-sol 60%",
            "hovered pie slice must update its accessibility value"
        )
        if let previewPath = ProcessInfo.processInfo.environment["RELAY_METER_RANKING_CARD_HOVER_PREVIEW_PATH"] {
            render(view, to: previewPath)
        }
        chart.mouseExited(with: hoverEvent)
        expect(detail.stringValue == "TOKENS %", "leaving the pie chart must restore its summary label")
        expect(
            chart.accessibilityValue() as? String == "gpt-5.6-sol 60% / claude-opus-5 30% / claude-sonnet-5 10%",
            "pie chart must restore its complete accessibility summary"
        )
        expect(chart.acceptsFirstResponder, "pie chart must expose a keyboard focus path")
        guard let rightArrow = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: 124
        ) else {
            fatalError("Top model token-share keyboard event unavailable")
        }
        chart.keyDown(with: rightArrow)
        expect(detail.stringValue == "gpt-5.6-sol · 60%", "keyboard navigation must expose the same pie-slice detail")
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
            "Launch at Login", "Spend",
            "English", "Requests + success rate", "Total tokens", "Failures", "Success rate",
            "Average latency", "Cache tokens", "Last 15m activity", "Today", "7d", "30d", "All",
            "Traffic", "Tokens", "Cache", "Latency", "Last 15m", "Trend chart", "Top model", "Last updated",
            "Enabled", "SHOW", "HIDE", "DELETE", "ADD ADAPTER",
            "Enabled adapters refresh in parallel; one failed adapter does not block the others.",
            "CHECK FOR UPDATES...", "CANCEL", "SAVE"
        ], in: copy, language: "English")
        expect(!copy.contains("Top API key"), "English settings must not offer the removed Top API key card")
    }

    @MainActor
    private static func testChineseSettingsCopy() {
        let copy = settingsCopy(language: .chinese)
        expectCopy([
            "Relay Meter 设置", "设置", "分别配置 adapter、菜单栏显示和监控卡片。",
            "ADAPTERS", "名称", "服务地址", "访问密钥", "new-api 用户 ID", "刷新间隔（秒）",
            "显示", "语言", "菜单栏默认显示", "时间范围", "卡片",
            "登录时启动", "花费",
            "简体中文", "请求数 + 成功率", "总 Token", "失败数", "成功率",
            "平均延迟", "缓存 Token", "最近 15 分钟活跃", "今天", "7 天", "30 天", "全部",
            "流量", "Token", "缓存", "延迟", "最近 15 分钟", "趋势曲线图", "Top 模型", "最后更新时间",
            "启用", "显示", "隐藏", "删除", "添加 ADAPTER",
            "启用的 adapter 会并发刷新；单个 adapter 失败不会阻止其他 adapter 展示。",
            "检查更新...", "取消", "保存"
        ], in: copy, language: "Chinese")
        expect(!copy.contains("Top API Key"), "Chinese settings must not offer the removed Top API key card")
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
                let controller = SettingsWindowController(
                    config: config,
                    launchAtLoginEnabled: true,
                    launchAtLoginRequiresApproval: false,
                    onSave: { _, _ in },
                    onCheckForUpdates: {}
                )
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
    private static func testLaunchAtLoginSetting() {
        var savedLaunchAtLogin: Bool?
        let controller = SettingsWindowController(
            config: AppConfig.defaultConfig,
            launchAtLoginEnabled: false,
            launchAtLoginRequiresApproval: false,
            onSave: { _, enabled in savedLaunchAtLogin = enabled },
            onCheckForUpdates: {}
        )
        guard let contentView = controller.window?.contentView,
              let toggle = findView(in: contentView, matching: {
                  $0.identifier?.rawValue == "launchAtLogin"
              }) as? NSButton,
              let save = findButton(in: contentView, titled: "SAVE") else {
            fatalError("launch-at-login settings controls missing")
        }
        expect(toggle.state == .off, "launch-at-login control must reflect system state")
        toggle.performClick(nil)
        save.performClick(nil)
        expect(savedLaunchAtLogin == true, "saving settings must apply the launch-at-login choice")

        let approvalController = SettingsWindowController(
            config: AppConfig.defaultConfig,
            launchAtLoginEnabled: true,
            launchAtLoginRequiresApproval: true,
            onSave: { _, _ in },
            onCheckForUpdates: {}
        )
        guard let approvalView = approvalController.window?.contentView,
              let approvalToggle = findView(in: approvalView, matching: {
                  $0.identifier?.rawValue == "launchAtLogin"
              }) as? NSButton else {
            fatalError("launch-at-login approval state missing")
        }
        expect(approvalToggle.title == "Approval Required", "pending login-item approval must be explicit")
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
        let host = request.url?.host ?? ""
        let path = request.url?.path ?? ""
        let body: String
        switch (host, path) {
        case ("cliproxy.test", _):
            body = #"{"items":[{"bucketStartMs":1782864000000,"totalRequests":2,"successCount":2,"failureCount":0,"totalTokens":150,"inputTokens":100,"outputTokens":50,"reasoningTokens":0,"cacheTokens":0,"estimatedCost":1.25}]}"#
        case ("sub2api.test", "/api/v1/admin/dashboard/stats"):
            body = #"{"code":0,"message":"ok","data":{"total_requests":3,"total_input_tokens":100,"total_output_tokens":50,"total_cache_creation_tokens":0,"total_cache_read_tokens":0,"total_tokens":150,"today_requests":3,"today_input_tokens":100,"today_output_tokens":50,"today_cache_creation_tokens":0,"today_cache_read_tokens":0,"today_tokens":150,"average_duration_ms":250,"rpm":1,"tpm":50}}"#
        case ("sub2api.test", "/api/v1/admin/dashboard/trend"):
            body = #"{"code":0,"message":"ok","data":{"trend":[{"date":"2026-08-13","requests":1,"input_tokens":40,"output_tokens":10,"cache_creation_tokens":0,"cache_read_tokens":0,"total_tokens":50,"actual_cost":1.25},{"date":"2026-08-14","requests":2,"input_tokens":60,"output_tokens":40,"cache_creation_tokens":0,"cache_read_tokens":0,"total_tokens":100,"actual_cost":0.75}]}}"#
        case ("sub2api.test", "/api/v1/admin/dashboard/models"):
            body = #"{"code":0,"message":"ok","data":{"models":[]}}"#
        case ("sub2api.test", "/api/v1/admin/dashboard/api-keys-trend"):
            body = #"{"code":0,"message":"ok","data":{"trend":[]}}"#
        case (_, "/api/status"):
            body = #"{"success":true,"message":"","data":{"enable_data_export":true,"quota_per_unit":500000}}"#
        case (_, "/api/data/"), (_, "/api/data"):
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
            let timestamp = components?.queryItems?.first { $0.name == "start_timestamp" }?.value ?? "0"
            body = #"{"success":true,"message":"","data":[{"created_at":\#(timestamp),"count":2,"token_used":40}]}"#
        case (_, "/api/log/"), (_, "/api/log"):
            body = #"{"success":true,"message":"","data":{"items":[{"created_at":1782864000,"type":2,"token_name":"test-key","model_name":"test-model","prompt_tokens":100,"completion_tokens":50,"use_time":1000,"quota":250000}]}}"#
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
