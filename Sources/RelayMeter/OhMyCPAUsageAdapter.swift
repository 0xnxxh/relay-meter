import Foundation

actor OhMyCPASessionStore {
    private struct Key: Hashable {
        let baseURL: String
        let credential: String
    }
    private var connections: [Key: OhMyCPAConnection] = [:]

    func connection(config: AppConfig, session: URLSession) -> OhMyCPAConnection {
        let key = Key(baseURL: config.baseURL, credential: config.managementKey)
        if let connection = connections[key] { return connection }
        let connection = OhMyCPAConnection(baseURL: config.baseURL, credential: config.managementKey, session: session)
        connections[key] = connection
        return connection
    }
}

// Console cookies must not cross accounts on the same host, or persist in the
// shared URLSession cookie jar. Redirects also must not forward the login body.
private final class OhMyCPANoRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

actor OhMyCPAConnection {
    private let baseURL: String
    private let credential: String
    private let session: URLSession
    private var cookie: HTTPCookie?
    private var loginTask: Task<HTTPCookie, Error>?
    private var cachedHeatmap: (value: OhMyCPAHeatmap, timezone: String, date: Date)?

    init(baseURL: String, credential: String, session: URLSession) {
        self.baseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        self.credential = credential
        let configuration = session.configuration
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.httpAdditionalHeaders = nil
        self.session = URLSession(configuration: configuration, delegate: OhMyCPANoRedirect(), delegateQueue: nil)
    }

    deinit { session.invalidateAndCancel() }

    func get<T: Decodable>(_ type: T.Type, path: String, query: [URLQueryItem]) async throws -> T {
        let current = try await authenticatedCookie()
        var request = try makeRequest(path: path, query: query)
        request.setValue("omc_session=\(current.value)", forHTTPHeaderField: "Cookie")
        var (data, response) = try await session.data(for: request)
        if (response as? HTTPURLResponse)?.statusCode == 401 {
            if cookie?.value == current.value { cookie = nil }
            let renewed = try await authenticatedCookie()
            request.setValue("omc_session=\(renewed.value)", forHTTPHeaderField: "Cookie")
            (data, response) = try await session.data(for: request)
        }
        try checkStatus(response)
        // HTTP bodies and decode diagnostics can contain server-echoed secrets.
        // Only a bounded local error is allowed into the dashboard and app log.
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(type, from: data)
        } catch {
            throw MonitorError.invalidResponse
        }
    }

    func heatmap(timezone: String) async throws -> OhMyCPAHeatmap {
        if let cached = cachedHeatmap, cached.timezone == timezone,
           Date().timeIntervalSince(cached.date) < 300,
           Calendar.current.isDateInToday(cached.date) {
            return cached.value
        }
        let value = try await get(OhMyCPAHeatmap.self, path: "/api/v1/management/dashboard/token-heatmap", query: [URLQueryItem(name: "tz", value: timezone)])
        guard value.timezone == timezone else { throw MonitorError.invalidResponse }
        cachedHeatmap = (value, timezone, Date())
        return value
    }

    private func authenticatedCookie() async throws -> HTTPCookie {
        if let cookie, let expiry = cookie.expiresDate, expiry > Date() { return cookie }
        if let loginTask { return try await loginTask.value }
        var request = try makeRequest(path: "/api/auth/login", query: [])
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["password": credential])
        let session = session
        let task = Task<HTTPCookie, Error> {
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else { throw MonitorError.invalidResponse }
            guard (200..<300).contains(response.statusCode) else {
                throw MonitorError.invalidStatus(response.statusCode, "")
            }
            struct Login: Decodable { let authenticated: Bool }
            guard (try? JSONDecoder().decode(Login.self, from: data))?.authenticated == true,
                  let url = response.url else { throw MonitorError.invalidResponse }
            let headers = response.allHeaderFields.reduce(into: [String: String]()) { fields, entry in
                fields[String(describing: entry.key)] = String(describing: entry.value)
            }
            guard let cookie = HTTPCookie.cookies(withResponseHeaderFields: headers, for: url)
                .first(where: { $0.name == "omc_session" }),
                  let expiry = cookie.expiresDate, expiry > Date() else { throw MonitorError.invalidResponse }
            return cookie
        }
        loginTask = task
        defer { loginTask = nil }
        let value = try await task.value
        cookie = value
        return value
    }

    private func makeRequest(path: String, query: [URLQueryItem]) throws -> URLRequest {
        guard var components = URLComponents(string: baseURL),
              ["http", "https"].contains(components.scheme?.lowercased() ?? ""),
              components.host != nil, components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil else {
            throw MonitorError.invalidResponse
        }
        components.path = components.path.replacingOccurrences(of: "/+$", with: "", options: .regularExpression) + path
        components.queryItems = query.isEmpty ? nil : query
        guard let url = components.url else { throw MonitorError.invalidResponse }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.httpShouldHandleCookies = false
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func checkStatus(_ response: URLResponse) throws {
        guard let response = response as? HTTPURLResponse else { throw MonitorError.invalidResponse }
        guard (200..<300).contains(response.statusCode) else {
            throw MonitorError.invalidStatus(response.statusCode, "")
        }
    }
}

struct OhMyCPAUsageAdapter {
    let config: AppConfig
    let connection: OhMyCPAConnection
    let logger: AppLogger

    func fetchSnapshot() async throws -> UsageSnapshot {
        let now = Date()
        let range = config.resolvedTimeRange
        guard let bounds = config.activityBounds(reference: now) else { throw MonitorError.invalidActivityDateRange }
        let query = rangeQuery(range, now: now)
        async let summary = connection.get(OhMyCPADashboard.self, path: "/api/v1/management/dashboard", query: query)
        async let recent = connection.get(OhMyCPADashboard.self, path: "/api/v1/management/dashboard", query: [URLQueryItem(name: "preset", value: "15m")])
        async let models = connection.get(OhMyCPAModels.self, path: "/api/v1/management/dashboard/models", query: query + [URLQueryItem(name: "group_by", value: "model")])
        async let activity = fetchActivity(bounds: bounds)
        let (summaryData, recentData, modelsData) = try await (summary, recent, models)
        guard summaryData.partialErrors.isEmpty, recentData.partialErrors.isEmpty, modelsData.partialErrors.isEmpty else {
            throw MonitorError.incompleteUsageData(config.resolvedLanguage)
        }
        logger.info("oh-my-cpa snapshot range=\(range.rawValue) requests=\(summaryData.requests.total)")
        return UsageSnapshot(
            sourceID: config.primaryAdapter.resolvedID,
            sourceName: config.primaryAdapter.displayName,
            platform: .ohMyCPA,
            selectedRange: range,
            scope: summaryData.scope,
            recent: recentData.scope,
            trendPoints: chartPoints(summaryData.requests.series, range: range),
            activity: await activity,
            // The model endpoint has no failure count; the ranking UI consumes
            // only model names, request counts and token counts.
            topModels: modelsData.models.filter { !$0.folded }
                .sorted { $0.tokens == $1.tokens ? $0.model < $1.model : $0.tokens > $1.tokens }
                .prefix(3).map { UsageRankingRow(label: $0.model, requests: $0.requests, failures: nil, tokens: $0.tokens) },
            refreshedAt: now
        )
    }

    private func rangeQuery(_ range: UsageTimeRange, now: Date) -> [URLQueryItem] {
        if range == .all { return [URLQueryItem(name: "preset", value: "all")] }
        let calendar = Calendar.current
        let days = range == .today ? 0 : (range == .sevenDays ? -6 : -29)
        let start = calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: now))!
        return [URLQueryItem(name: "from", value: String(Int(start.timeIntervalSince1970 * 1000))),
                URLQueryItem(name: "to", value: String(Int(now.timeIntervalSince1970 * 1000)))]
    }

    private func chartPoints(_ series: [OhMyCPAPoint], range: UsageTimeRange) -> [UsageTrendPoint] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = range == .today ? "HH:mm" : "MM-dd"
        let grouped = Dictionary(grouping: series) { point in
            let date = Date(timeIntervalSince1970: Double(point.t) / 1000)
            return range == .today ? calendar.dateInterval(of: .hour, for: date)!.start : calendar.startOfDay(for: date)
        }
        return grouped.keys.sorted().map { start in
            let points = grouped[start]!
            return UsageTrendPoint(bucketStartMs: Int(start.timeIntervalSince1970 * 1000), label: formatter.string(from: start), requests: points.reduce(0) { $0 + $1.v }, failures: points.reduce(0) { $0 + $1.f }, tokens: points.reduce(0) { $0 + $1.tokens })
        }
    }

    private func fetchActivity(bounds: UsageDateBounds) async -> UsageActivityDataset {
        do {
            let heatmap = try await connection.heatmap(timezone: TimeZone.current.identifier)
            let asOf = Date(timeIntervalSince1970: Double(heatmap.asOfMs) / 1000)
            let firstStored = heatmap.firstStoredMs.map { Date(timeIntervalSince1970: Double($0) / 1000) }
            let days = heatmap.days.filter { $0.fromMs > 0 && $0.toMs >= $0.fromMs }
            let points = days.map {
                UsageTrendPoint(bucketStartMs: $0.fromMs, label: "", requests: $0.requests, failures: $0.failures, tokens: $0.tokens)
            }
            let known = days.compactMap { day -> UsageDateBounds? in
                let start = Date(timeIntervalSince1970: Double(day.fromMs) / 1000)
                let end = Date(timeIntervalSince1970: Double(day.toMs) / 1000)
                guard let firstStored, end >= firstStored, start <= asOf else { return nil }
                return UsageDateBounds(start: start, end: min(end, asOf))
            }
            return UsageActivitySeries.dataset(points: points, bounds: bounds, knownBounds: known)
        } catch {
            logger.error("oh-my-cpa activity failed \(error.localizedDescription)")
            return UsageActivitySeries.unavailable(bounds: bounds, reason: .requestFailed)
        }
    }
}

private struct OhMyCPADashboard: Decodable {
    struct Requests: Decodable {
        let total: Int
        let success: Int
        let failed: Int
        let series: [OhMyCPAPoint]
    }
    struct Tokens: Decodable {
        let total: Int
        let input: Int
        let output: Int
        let reasoning: Int
        let cached: Int
        let cacheRead: Int
    }
    struct Metrics: Decodable {
        let cost: Double
        let costSource: String
        let avgLatencyMs: Double?
        let avgTtftMs: Double?
    }
    let requests: Requests
    let tokens: Tokens
    let metrics: Metrics
    let partialErrors: [String]

    var scope: UsageScope {
        var scope = UsageScope()
        scope.totalRequests = requests.total
        scope.successCount = requests.success
        scope.failureCount = requests.failed
        scope.totalTokens = tokens.total
        scope.inputTokens = tokens.input
        scope.outputTokens = tokens.output
        scope.reasoningTokens = tokens.reasoning
        scope.cacheTokens = max(0, tokens.cacheRead == 0 ? tokens.cached : tokens.cacheRead)
        let prompt = max(0, tokens.input > 0 ? tokens.input : tokens.total - tokens.output)
        scope.cacheRateInputTokens = scope.cacheTokens > prompt ? prompt + scope.cacheTokens : prompt
        if metrics.costSource == "estimated" {
            scope.costUSD = metrics.cost
            scope.costIsEstimated = true
        }
        if let latency = metrics.avgLatencyMs, requests.total > 0 {
            scope.weightedLatencyTotal = Int(latency * Double(requests.total))
            scope.latencyWeight = requests.total
        }
        if let ttft = metrics.avgTtftMs, requests.total > 0 {
            scope.weightedTtftTotal = Int(ttft * Double(requests.total))
            scope.ttftWeight = requests.total
        }
        return scope
    }
}

private struct OhMyCPAPoint: Decodable {
    let t: Int
    let v: Int
    let f: Int
    let tokens: Int
}

private struct OhMyCPAModels: Decodable {
    struct Model: Decodable {
        let model: String
        let folded: Bool
        let tokens: Int
        let requests: Int
    }
    let models: [Model]
    let partialErrors: [String]
}

struct OhMyCPAHeatmap: Decodable {
    struct Day: Decodable {
        let fromMs: Int
        let toMs: Int
        let tokens: Int
        let requests: Int
        let failures: Int
    }
    let asOfMs: Int
    let timezone: String
    let firstStoredMs: Int?
    let days: [Day]
}
