import AppKit
import Foundation

enum OhMyCPATests {
    @MainActor
    static func run() async {
        for range in UsageTimeRange.allCases {
            let config = configuration(host: "omc-\(range.rawValue).test", range: range)
            let session = stubSession()
            let client = UsageClient(config: config, session: session)
            OMCStub.reset()
            let dashboard = try! await client.fetchDashboardSnapshot()
            let snapshot = dashboard.adapters[0]
            expect(snapshot.platform.rawValue == "ohMyCPA", "OMC source identity must survive fetching")
            expect(snapshot.scope.totalRequests == 50 && snapshot.scope.failureCount == 2, "OMC cards must use window totals, not a truncated series")
            expect(snapshot.scope.totalTokens == 500 && snapshot.scope.inputTokens == 320, "OMC token breakdown must map directly")
            expect(snapshot.scope.cacheTokens == 80, "OMC cache read and legacy cached fields must not be added together")
            expect(abs(snapshot.scope.cacheRate - 0.25) < 0.0001, "OMC cache ratio must use prompt tokens")
            expect(snapshot.scope.avgLatencyMs == 123 && snapshot.scope.avgTtftMs == 25, "fractional millisecond averages must decode")
            expect(snapshot.scope.costUSD == 1.25 && snapshot.scope.costIsEstimated, "OMC complete request-time pricing is estimated USD")
            expect(snapshot.recent.totalRequests == 3, "recent cards must use a separate 15-minute window")
            expect(snapshot.trendPoints.reduce(0) { $0 + $1.requests } == 50, "the complete OMC series must reach the chart")
            expect(dashboard.aggregate.trendPoints.reduce(0) { $0 + $1.requests } == 50, "the aggregate must not drop older chart buckets")
            expect(snapshot.topModels.map(\.label) == ["model-a", "model-b"], "a folded remainder is not a model")
            expect(snapshot.topModels[0].tokens == 300, "OMC model ranking must retain token volume")
            expect(snapshot.topModels[0].successRate == nil, "OMC must not invent per-model success rates")
            expect(snapshot.activity.days.last?.requests == 3, "heatmap must use daily request totals")
            expect(snapshot.activity.days.last?.failures == 1, "heatmap failures must remain available")
            expect(snapshot.activity.days.first?.state == .unknown, "days before first stored usage must remain unknown")
            expect(snapshot.activity.days.suffix(2).first?.state == .knownZero, "stored empty days must remain known zero")
            expect(config.primaryAdapter.monitoringURL?.absoluteString == "https://omc-\(range.rawValue).test/omc/", "monitoring URL must retain the console mount path")

            let requests = OMCStub.requests()
            let login = requests.first { $0.url?.path.hasSuffix("/api/auth/login") == true }!
            expect(login.httpMethod == "POST", "OMC must sign in through the console login endpoint")
            let body = login.httpBody ?? Data()
            let payload = (try? JSONSerialization.jsonObject(with: body)) as? [String: String]
            expect(payload?["password"] == "test-omc-key", "OMC login must send the access key in the JSON body")
            let reads = requests.filter { $0.httpMethod == "GET" }
            expect(reads.count == 4, "OMC must read summary, recent window, models and daily heatmap")
            expect(reads.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == nil && $0.value(forHTTPHeaderField: "Cookie") == "omc_session=test-session" }, "OMC reads must use only the isolated session cookie")
            let main = reads.first { $0.url?.path.hasSuffix("/dashboard") == true && query($0, "preset") != "15m" }!
            if range == .all {
                expect(query(main, "preset") == "all" && query(main, "from") == nil, "all-time must use the server's permanent usage window")
            } else {
                let calendar = Calendar.current
                let offset = range == .today ? 0 : (range == .sevenDays ? -6 : -29)
                let expected = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: Date()))!
                expect(query(main, "from") == String(Int(expected.timeIntervalSince1970 * 1000)), "range bounds must follow the viewer's calendar")
            }
            expect(reads.contains { query($0, "tz") == TimeZone.current.identifier }, "heatmap must explicitly request the viewer's timezone")
            _ = try! await client.fetchDashboardSnapshot()
            expect(OMCStub.requests().filter { $0.httpMethod == "POST" }.count == 1, "refreshes must reuse the in-memory login session")
            expect(OMCStub.requests().filter { $0.url?.path.hasSuffix("/token-heatmap") == true }.count == 1, "refreshes must reuse the five-minute heatmap cache")
        }

        for source in ["partial", "placeholder"] {
            OMCStub.reset(costSource: source)
            let snapshot = try! await UsageClient(config: configuration(host: "omc-\(source).test"), session: stubSession()).fetchDashboardSnapshot()
            expect(snapshot.adapters[0].scope.costUSD == nil && snapshot.aggregate.scope.costUSD == nil, "unpriced requests must not become a complete spend total")
        }

        OMCStub.reset(failHeatmap: true)
        let unavailable = try! await UsageClient(config: configuration(host: "omc-no-heatmap.test"), session: stubSession()).fetchSnapshot()
        expect(unavailable.scope.totalRequests == 50 && unavailable.activity.availability == .unavailable, "heatmap failure must remain visible while cards continue working")

        for failure in ["login", "partial", "models"] {
            OMCStub.reset(failure: failure)
            do {
                _ = try await UsageClient(config: configuration(host: "omc-fail-\(failure).test"), session: stubSession()).fetchSnapshot()
                fatalError("OMC \(failure) failure must not look successful")
            } catch {
                expect(!error.localizedDescription.contains("test-omc-key"), "OMC errors must never echo credentials")
            }
        }

        OMCStub.reset(expireSession: true)
        _ = try! await UsageClient(config: configuration(host: "omc-expiry.test"), session: stubSession()).fetchSnapshot()
        expect(OMCStub.requests().filter { $0.httpMethod == "POST" }.count == 2, "an invalidated session must sign in once again")

        OMCStub.reset()
        let root = configuration(host: "omc-root.test", mount: "")
        _ = try! await UsageClient(config: root, session: stubSession()).fetchSnapshot()
        expect(OMCStub.requests().allSatisfy { $0.url?.path.hasPrefix("/api/") == true }, "a root-mounted console must not gain an invented /omc prefix")

        OMCStub.reset()
        var mixed = configuration(host: "omc-mixed.test")
        var second = mixed.adapters[0]
        second.id = "omc-second"
        second.managementKey = "second-test-key"
        mixed.adapters.append(second)
        let mixedDashboard = try! await UsageClient(config: mixed, session: stubSession()).fetchDashboardSnapshot()
        expect(mixedDashboard.aggregate.scope.totalRequests == 100, "multiple OMC adapters must aggregate window totals")
        expect(OMCStub.requests().filter { $0.httpMethod == "POST" }.count == 2, "credentials on the same host must have separate login sessions")
        expect(mixedDashboard.aggregate.topModels.allSatisfy { $0.successRate == nil }, "aggregate rankings must preserve unknown failure counts")

        var knownCache = UsageScope()
        knownCache.inputTokens = 100
        knownCache.cacheTokens = 25
        var legacyCache = UsageScope()
        legacyCache.inputTokens = 20
        legacyCache.cacheTokens = 30
        legacyCache.cacheRateInputTokens = 50
        knownCache.add(legacyCache)
        expect(abs(knownCache.cacheRate - 55.0 / 150) < 0.0001, "mixed-channel cache ratio must sum each adapter's prompt denominator")
        testSettings()
        await testLiveConsoleIfConfigured()
    }

    @MainActor
    private static func testLiveConsoleIfConfigured() async {
        guard let url = ProcessInfo.processInfo.environment["RELAY_METER_OMC_TEST_URL"],
              let key = ProcessInfo.processInfo.environment["RELAY_METER_OMC_TEST_KEY"] else { return }
        var config = configuration(host: "unused.test")
        config.adapters[0].baseURL = url
        config.adapters[0].managementKey = key
        for range in UsageTimeRange.allCases {
            config.timeRange = range
            let dashboard = try! await UsageClient(config: config).fetchDashboardSnapshot()
            let expected = range == .all ? 5 : (range == .today ? 3 : 4)
            expect(dashboard.aggregate.scope.totalRequests == expected, "live OMC handler must return the selected window's retained usage facts")
            expect(dashboard.aggregate.scope.failureCount == 1, "live OMC handler must retain failed requests")
            expect(dashboard.aggregate.scope.totalTokens == expected * 1500, "live OMC token totals must agree with stored events")
            expect(dashboard.aggregate.scope.avgLatencyMs == 250, "live OMC latency must decode")
            expect(dashboard.adapters[0].activity.days.reduce(0) { $0 + $1.requests } == 5, "live OMC heatmap must cover all retained fixture days")
            expect(dashboard.aggregate.topModels.count == 2, "live OMC model groups must decode")
            let view = SnapshotMenuView(dashboard: dashboard, config: config, texts: TextBundle.forLanguage(.english))
            view.setFrameSize(view.fittingSize)
            view.layoutSubtreeIfNeeded()
            expect(view.fittingSize.height > 0, "live OMC snapshot must lay out through the normal menu view")
            if range == .today, let path = ProcessInfo.processInfo.environment["RELAY_METER_OMC_PREVIEW_PATH"] {
                let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
                view.cacheDisplay(in: view.bounds, to: bitmap)
                try! bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
            }
        }
        print("Live OMC handler integration passed")
    }

    @MainActor
    private static func testSettings() {
        let config = configuration(host: "omc-settings.test")
        var saved: AppConfig?
        let controller = SettingsWindowController(config: config, launchAtLoginEnabled: false, launchAtLoginRequiresApproval: false, onSave: { value, _ in saved = value }, onCheckForUpdates: {})
        func find(_ view: NSView, _ predicate: (NSView) -> Bool) -> NSView? {
            if predicate(view) { return view }
            for child in view.subviews {
                if let result = find(child, predicate) { return result }
            }
            return nil
        }
        let content = controller.window!.contentView!
        let save = find(content) { ($0 as? NSButton)?.title == "SAVE" } as! NSButton
        expect(find(content) { ($0 as? PixelPopupButton)?.selectedRepresentedObject as? String == "ohMyCPA" } != nil, "Settings must offer the OMC channel")
        save.performClick(nil)
        expect(saved?.primaryAdapter.platform.rawValue == "ohMyCPA", "Settings must preserve the OMC channel when saving")
        expect(saved?.primaryAdapter.managementKey == "test-omc-key", "Settings must preserve the editable access key")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("omc-config-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ConfigStore(url: directory.appendingPathComponent("config.json"))
        try! store.save(saved!)
        expect((try! store.load()).primaryAdapter.platform.rawValue == "ohMyCPA", "OMC config must persist and reload through ConfigStore")
    }

    private static func configuration(host: String, range: UsageTimeRange = .today, mount: String = "/omc") -> AppConfig {
        let json = #"{"adapters":[{"id":"omc","name":"Oh My CPA","platform":"ohMyCPA","baseURL":"https://\#(host)\#(mount)/","managementKey":"test-omc-key"}],"baseURL":"https://\#(host)\#(mount)","managementKey":"test-omc-key","timeRange":"\#(range.rawValue)"}"#
        return try! JSONDecoder().decode(AppConfig.self, from: Data(json.utf8))
    }

    private static func stubSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [OMCStub.self]
        return URLSession(configuration: config)
    }

    private static func query(_ request: URLRequest, _ name: String) -> String? {
        URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == name }?.value
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() { fatalError(message) }
    }
}

private final class OMCStub: URLProtocol {
    private static let lock = NSLock()
    private static var recorded: [URLRequest] = []
    private static var costSource = "estimated"
    private static var failHeatmap = false
    private static var failure = ""
    private static var expireSession = false

    static func reset(costSource: String = "estimated", failHeatmap: Bool = false, failure: String = "", expireSession: Bool = false) {
        lock.lock()
        defer { lock.unlock() }
        recorded = []
        Self.costSource = costSource
        Self.failHeatmap = failHeatmap
        Self.failure = failure
        Self.expireSession = expireSession
    }

    static func requests() -> [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        var recordedRequest = request
        if recordedRequest.httpBody == nil, let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                data.append(buffer, count: count)
            }
            recordedRequest.httpBody = data
        }
        Self.lock.lock()
        Self.recorded.append(recordedRequest)
        let costSource = Self.costSource
        let failure = Self.failure
        let failHeatmap = Self.failHeatmap
        let expires = Self.expireSession && request.httpMethod != "POST"
        if expires { Self.expireSession = false }
        Self.lock.unlock()
        let path = request.url!.path
        let today = Calendar.current.startOfDay(for: Date())
        let dayMS = Int(today.timeIntervalSince1970 * 1000)
        var status = 200
        var headers = ["Content-Type": "application/json"]
        let body: String
        if path.hasSuffix("/auth/login") {
            status = failure == "login" ? 401 : 200
            headers["Set-Cookie"] = "omc_session=test-session; Path=/; HttpOnly; Max-Age=43200"
            body = failure == "login" ? #"{"error":"invalid test-omc-key"}"# : #"{"authenticated":true}"#
        } else if expires {
            status = 401
            body = #"{"error":"authentication required"}"#
        } else if path.hasSuffix("/token-heatmap") {
            status = failHeatmap ? 503 : 200
            body = #"{"as_of_ms":\#(dayMS + 3600000),"timezone":"\#(TimeZone.current.identifier)","first_stored_ms":\#(dayMS - 86400000),"days":[{"day":"ignored","from_ms":\#(dayMS - 86400000),"to_ms":\#(dayMS - 1),"tokens":0,"requests":0,"failures":0},{"day":"ignored","from_ms":\#(dayMS),"to_ms":\#(dayMS + 3600000),"tokens":30,"requests":3,"failures":1}]}"#
        } else if path.hasSuffix("/models") {
            body = #"{"partial_errors":\#(failure == "models" ? "[\"read failed\"]" : "[]"),"models":[{"model":"model-a","folded":false,"tokens":300,"requests":30},{"model":"model-b","folded":false,"tokens":200,"requests":20},{"model":"","folded":true,"tokens":9999,"requests":100}]}"#
        } else if path.hasSuffix("/dashboard") {
            let isRecent = request.url!.query?.contains("preset=15m") == true
            let series = (0..<50).map { #"{"t":\#(dayMS - (49 - $0) * 86400000),"v":1,"f":0,"tokens":10}"# }.joined(separator: ",")
            body = #"{"requests":{"total":\#(isRecent ? 3 : 50),"success":48,"failed":2,"series":[\#(series)]},"tokens":{"total":500,"input":320,"output":180,"reasoning":40,"cached":80,"cache_read":80,"cache_creation":20},"metrics":{"avg_latency_ms":123.75,"avg_ttft_ms":25.5,"cache_rate":25,"cost":1.25,"cost_source":"\#(costSource)"},"partial_errors":\#(failure == "partial" ? "[\"read failed\"]" : "[]")}"#
        } else {
            status = 404
            body = #"{"error":"unexpected path"}"#
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}
