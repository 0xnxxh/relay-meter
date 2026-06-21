import Foundation

final class UsageClient {
    private let config: AppConfig
    private let session: URLSession
    private let logger: AppLogger

    init(config: AppConfig, session: URLSession = .shared, logger: AppLogger = .shared) {
        self.config = config
        self.session = session
        self.logger = logger
    }

    func fetchSnapshot() async throws -> UsageSnapshot {
        switch config.resolvedPlatform {
        case .cliproxyapiPro:
            return try await CLIProxyAPIProUsageAdapter(config: config, session: session, logger: logger).fetchSnapshot()
        case .sub2api:
            return try await Sub2APIUsageAdapter(config: config, session: session, logger: logger).fetchSnapshot()
        case .newApi:
            return try await NewAPIUsageAdapter(config: config, session: session, logger: logger).fetchSnapshot()
        }
    }

    func fetchDashboardSnapshot() async throws -> UsageDashboardSnapshot {
        let adapters = config.resolvedAdapters
        guard !adapters.isEmpty else {
            throw MonitorError.noAdaptersConfigured
        }
        var snapshots: [UsageSnapshot] = []
        var errors: [AdapterSnapshotError] = []

        await withTaskGroup(of: AdapterFetchResult.self) { group in
            for adapter in adapters {
                group.addTask { [config, session, logger] in
                    let scopedConfig = config.scoped(to: adapter)
                    do {
                        var snapshot = try await UsageClient(config: scopedConfig, session: session, logger: logger).fetchSnapshot()
                        snapshot.sourceID = adapter.resolvedID
                        snapshot.sourceName = adapter.displayName
                        return .success(snapshot)
                    } catch {
                        return .failure(AdapterSnapshotError(
                            adapterName: adapter.displayName,
                            message: error.localizedDescription
                        ))
                    }
                }
            }

            for await result in group {
                switch result {
                case .success(let snapshot):
                    snapshots.append(snapshot)
                case .failure(let error):
                    errors.append(error)
                }
            }
        }

        snapshots.sort { $0.sourceName.localizedCaseInsensitiveCompare($1.sourceName) == .orderedAscending }
        errors.sort { $0.adapterName.localizedCaseInsensitiveCompare($1.adapterName) == .orderedAscending }
        if snapshots.isEmpty, let firstError = errors.first {
            throw MonitorError.allAdaptersFailed(firstError.message)
        }

        let aggregate = aggregateSnapshot(from: snapshots, range: config.resolvedTimeRange)
        logger.info("dashboard snapshot adapters=\(snapshots.count) errors=\(errors.count) requests=\(aggregate.scope.totalRequests)")
        return UsageDashboardSnapshot(
            selectedRange: config.resolvedTimeRange,
            aggregate: aggregate,
            adapters: snapshots,
            errors: errors,
            refreshedAt: Date()
        )
    }
}

private enum AdapterFetchResult {
    case success(UsageSnapshot)
    case failure(AdapterSnapshotError)
}

private struct CLIProxyAPIProUsageAdapter {
    let config: AppConfig
    let session: URLSession
    let logger: AppLogger

    func fetchSnapshot() async throws -> UsageSnapshot {
        let range = config.resolvedTimeRange
        let fromMs = rangeStartMs(range)
        let interval = aggregateInterval(range)
        let limit = aggregateLimit(range)

        async let today = fetchScope(fromMs: fromMs, interval: interval, limit: limit, groupBy: [])
        async let recent = fetchScope(fromMs: minutesAgoMs(15), groupBy: [])
        async let models = fetchScope(fromMs: fromMs, interval: interval, limit: limit, groupBy: ["model"])
        async let apiKeys = fetchScope(fromMs: fromMs, interval: interval, limit: limit, groupBy: ["api_key_hash"])

        let todayBuckets = try await today
        let recentBuckets = try await recent
        let modelBuckets = try await models
        let apiKeyBuckets = try await apiKeys
        logger.info("cliproxyapi-pro snapshot range=\(range.rawValue) interval=\(interval) buckets=\(todayBuckets.count) recent=\(recentBuckets.count) models=\(modelBuckets.count) apiKeys=\(apiKeyBuckets.count)")

        return UsageSnapshot(
            sourceID: "primary",
            sourceName: config.primaryAdapter.displayName,
            platform: .cliproxyapiPro,
            selectedRange: range,
            scope: summarize(todayBuckets),
            recent: summarize(recentBuckets),
            trendPoints: trendPoints(todayBuckets, range: range),
            topModels: rank(modelBuckets: modelBuckets, label: \.model),
            topApiKeys: rank(modelBuckets: apiKeyBuckets, label: \.apiKeyHash).map(maskHashRow),
            refreshedAt: Date()
        )
    }

    private func fetchScope(fromMs: Int, interval: String = "hour", limit: Int? = nil, groupBy: [String]) async throws -> [UsageAggregateBucket] {
        guard var components = URLComponents(url: usageURL(path: "aggregates"), resolvingAgainstBaseURL: false) else {
            throw MonitorError.invalidBaseURL(config.baseURL)
        }

        var queryItems = [
            URLQueryItem(name: "from_ms", value: String(fromMs)),
            URLQueryItem(name: "to_ms", value: String(nowMs())),
            URLQueryItem(name: "interval", value: interval),
            URLQueryItem(name: "limit", value: String(limit ?? (groupBy.isEmpty ? 48 : 200)))
        ]
        if !groupBy.isEmpty {
            queryItems.append(URLQueryItem(name: "group_by", value: groupBy.joined(separator: ",")))
        }
        components.queryItems = queryItems

        let response: AggregateResponse = try await requestJSON(
            components.url,
            auth: .platform(config: config),
            session: session,
            logger: logger,
            logName: "cliproxyapi-pro aggregates"
        )
        return response.items
    }

    private func usageURL(path: String) -> URL {
        let trimmed = trimmedBaseURL(config.baseURL)
        if trimmed.hasSuffix("/v0/management") {
            return URL(string: "\(trimmed)/usage/\(path)")!
        }
        if trimmed.hasSuffix("/v0") {
            return URL(string: "\(trimmed)/management/usage/\(path)")!
        }
        return URL(string: "\(trimmed)/v0/management/usage/\(path)")!
    }

    private func rank(modelBuckets buckets: [UsageAggregateBucket], label: (UsageAggregateBucket) -> String?) -> [UsageRankingRow] {
        rankBuckets(buckets, label: label)
    }
}

private struct Sub2APIUsageAdapter {
    let config: AppConfig
    let session: URLSession
    let logger: AppLogger

    func fetchSnapshot() async throws -> UsageSnapshot {
        let range = config.resolvedTimeRange
        let query = dateRangeQuery(range)
        async let stats: Sub2APIEnvelope<Sub2APIStats> = get("/api/v1/admin/dashboard/stats")
        async let trend: Sub2APIEnvelope<Sub2APITrendPayload> = get("/api/v1/admin/dashboard/trend?\(query)&granularity=\(range == .today ? "hour" : "day")")
        async let models: Sub2APIEnvelope<Sub2APIModelsPayload> = get("/api/v1/admin/dashboard/models?\(query)&model_source=requested")
        async let apiKeys: Sub2APIEnvelope<Sub2APIAPIKeyTrendPayload> = get("/api/v1/admin/dashboard/api-keys-trend?\(query)&granularity=day&limit=3")

        let statsData = try await stats.data
        let trendPoints = try await trend.data.trend.map { point in
            UsageTrendPoint(
                bucketStartMs: parseSub2APIDateMs(point.date),
                label: point.date,
                requests: point.requests,
                failures: 0,
                tokens: point.totalTokens
            )
        }
        let modelRows = try await models.data.models.map {
            UsageRankingRow(label: $0.model.ifEmpty("-"), requests: $0.requests, failures: 0, tokens: $0.totalTokens)
        }
        let apiKeyRows = try await apiKeys.data.trend.map {
            UsageRankingRow(label: $0.keyName.ifEmpty("#\($0.apiKeyId)"), requests: $0.requests, failures: 0, tokens: $0.tokens)
        }

        logger.info("sub2api snapshot range=\(range.rawValue) trend=\(trendPoints.count) models=\(modelRows.count) apiKeys=\(apiKeyRows.count)")
        return UsageSnapshot(
            sourceID: "primary",
            sourceName: config.primaryAdapter.displayName,
            platform: .sub2api,
            selectedRange: range,
            scope: statsData.scope(for: range),
            recent: statsData.recentScope(),
            trendPoints: trendPoints.sorted { $0.bucketStartMs < $1.bucketStartMs }.suffix(30).map { $0 },
            topModels: modelRows.sortedForRanking().prefix(3).map { $0 },
            topApiKeys: apiKeyRows.sortedForRanking().prefix(3).map { $0 },
            refreshedAt: Date()
        )
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        try await requestJSON(
            platformURL(config: config, path: path),
            auth: .platform(config: config),
            session: session,
            logger: logger,
            logName: "sub2api \(path)"
        )
    }
}

private struct NewAPIUsageAdapter {
    let config: AppConfig
    let session: URLSession
    let logger: AppLogger

    func fetchSnapshot() async throws -> UsageSnapshot {
        let range = config.resolvedTimeRange
        let fromSeconds = rangeStartMs(range) / 1_000
        let toSeconds = nowMs() / 1_000

        async let logs: NewAPIEnvelope<NewAPILogPage> = get("/api/log/?type=2&start_timestamp=\(fromSeconds)&end_timestamp=\(toSeconds)&p=0&page_size=200")
        async let recentLogs: NewAPIEnvelope<NewAPILogPage> = get("/api/log/?type=2&start_timestamp=\(minutesAgoMs(15) / 1_000)&end_timestamp=\(toSeconds)&p=0&page_size=200")

        let logItems = try await logs.data.items
        let recentItems = try await recentLogs.data.items
        logger.info("new-api snapshot range=\(range.rawValue) logs=\(logItems.count) recent=\(recentItems.count)")

        return UsageSnapshot(
            sourceID: "primary",
            sourceName: config.primaryAdapter.displayName,
            platform: .newApi,
            selectedRange: range,
            scope: scope(from: logItems),
            recent: scope(from: recentItems),
            trendPoints: trendPoints(from: logItems, range: range),
            topModels: ranking(from: logItems, key: \.modelName),
            topApiKeys: ranking(from: logItems, key: \.tokenName),
            refreshedAt: Date()
        )
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        try await requestJSON(
            platformURL(config: config, path: path),
            auth: .platform(config: config),
            session: session,
            logger: logger,
            logName: "new-api \(path)"
        )
    }

    private func scope(from logs: [NewAPILog]) -> UsageScope {
        var scope = UsageScope()
        for log in logs {
            let failed = log.type == 5
            scope.totalRequests += 1
            scope.successCount += failed ? 0 : 1
            scope.failureCount += failed ? 1 : 0
            scope.inputTokens += log.promptTokens
            scope.outputTokens += log.completionTokens
            scope.totalTokens += log.promptTokens + log.completionTokens
            if log.useTime > 0 {
                scope.weightedLatencyTotal += log.useTime
                scope.latencyWeight += 1
            }
        }
        return scope
    }

    private func trendPoints(from logs: [NewAPILog], range: UsageTimeRange) -> [UsageTrendPoint] {
        var rowsByBucket: [Int: UsageTrendPoint] = [:]
        for log in logs {
            let bucket = bucketStartMs(timestampSeconds: log.createdAt, range: range)
            let previous = rowsByBucket[bucket] ?? UsageTrendPoint(
                bucketStartMs: bucket,
                label: trendLabel(bucket, range: range),
                requests: 0,
                failures: 0,
                tokens: 0
            )
            rowsByBucket[bucket] = UsageTrendPoint(
                bucketStartMs: bucket,
                label: previous.label,
                requests: previous.requests + 1,
                failures: previous.failures + (log.type == 5 ? 1 : 0),
                tokens: previous.tokens + log.promptTokens + log.completionTokens
            )
        }
        return rowsByBucket.values.sorted { $0.bucketStartMs < $1.bucketStartMs }.suffix(30).map { $0 }
    }

    private func ranking(from logs: [NewAPILog], key: (NewAPILog) -> String) -> [UsageRankingRow] {
        var rows: [String: UsageRankingRow] = [:]
        for log in logs {
            let label = key(log).ifEmpty("-")
            let previous = rows[label] ?? UsageRankingRow(label: label, requests: 0, failures: 0, tokens: 0)
            rows[label] = UsageRankingRow(
                label: label,
                requests: previous.requests + 1,
                failures: previous.failures + (log.type == 5 ? 1 : 0),
                tokens: previous.tokens + log.promptTokens + log.completionTokens
            )
        }
        return Array(rows.values).sortedForRanking().prefix(3).map { $0 }
    }
}

private enum RequestAuth {
    case platform(config: AppConfig)

    func apply(to request: inout URLRequest) {
        switch self {
        case .platform(let config):
            request.setValue(authValue(config: config), forHTTPHeaderField: config.resolvedAuthHeaderName)
            if config.resolvedPlatform == .newApi, let userID = config.newApiUserID {
                request.setValue(String(userID), forHTTPHeaderField: "New-Api-User")
            }
        }
    }

    private func authValue(config: AppConfig) -> String {
        if config.resolvedPlatform == .cliproxyapiPro,
           config.resolvedAuthHeaderName.caseInsensitiveCompare("Authorization") == .orderedSame {
            return config.managementKey.lowercased().hasPrefix("bearer ") ? config.managementKey : "Bearer \(config.managementKey)"
        }
        return config.managementKey
    }
}

private func requestJSON<T: Decodable>(
    _ url: URL?,
    auth: RequestAuth,
    session: URLSession,
    logger: AppLogger,
    logName: String
) async throws -> T {
    guard let url else { throw MonitorError.invalidResponse }
    var request = URLRequest(url: url)
    request.timeoutInterval = 15
    auth.apply(to: &request)
    logger.info("GET \(logName) path=\(url.path)")
    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
        throw MonitorError.invalidResponse
    }
    guard (200..<300).contains(httpResponse.statusCode) else {
        let body = String(data: data, encoding: .utf8) ?? ""
        logger.error("\(logName) status=\(httpResponse.statusCode) body=\(body.prefix(200))")
        throw MonitorError.invalidStatus(httpResponse.statusCode, body)
    }
    do {
        return try sharedJSONDecoder.decode(T.self, from: data)
    } catch {
        logger.error("\(logName) decode failed \(error.localizedDescription)")
        throw error
    }
}

private let sharedJSONDecoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .iso8601
    return decoder
}()

private func trimmedBaseURL(_ value: String) -> String {
    value.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
}

private func platformURL(config: AppConfig, path: String) -> URL? {
    URL(string: "\(trimmedBaseURL(config.baseURL))/\(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))")
}

private func startOfTodayMs() -> Int {
    let start = Calendar.current.startOfDay(for: Date())
    return Int(start.timeIntervalSince1970 * 1_000)
}

private func rangeStartMs(_ range: UsageTimeRange) -> Int {
    let todayStart = startOfTodayMs()
    let dayMs = 24 * 60 * 60 * 1_000
    switch range {
    case .today:
        return todayStart
    case .sevenDays:
        return todayStart - 6 * dayMs
    case .thirtyDays:
        return todayStart - 29 * dayMs
    case .all:
        return 0
    }
}

private func nowMs() -> Int {
    Int(Date().timeIntervalSince1970 * 1_000)
}

private func minutesAgoMs(_ minutes: Int) -> Int {
    Int(Date().addingTimeInterval(TimeInterval(-minutes * 60)).timeIntervalSince1970 * 1_000)
}

private func aggregateInterval(_ range: UsageTimeRange) -> String {
    range == .today ? "hour" : "day"
}

private func aggregateLimit(_ range: UsageTimeRange) -> Int {
    switch range {
    case .today: return 48
    case .sevenDays: return 100
    case .thirtyDays: return 400
    case .all: return 2_000
    }
}

private func dateRangeQuery(_ range: UsageTimeRange) -> String {
    let start = Date(timeIntervalSince1970: TimeInterval(rangeStartMs(range)) / 1_000)
    let end = Date()
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return "start_date=\(formatter.string(from: start))&end_date=\(formatter.string(from: end))"
}

private func summarize(_ buckets: [UsageAggregateBucket]) -> UsageScope {
    var summary = UsageScope()
    for bucket in buckets {
        summary.totalRequests += bucket.totalRequests
        summary.successCount += bucket.successCount
        summary.failureCount += bucket.failureCount
        summary.totalTokens += bucket.totalTokens
        summary.inputTokens += bucket.inputTokens ?? 0
        summary.outputTokens += bucket.outputTokens ?? 0
        summary.reasoningTokens += bucket.reasoningTokens ?? 0
        summary.cacheTokens += bucket.cacheTokens ?? 0
        if let latency = bucket.avgLatencyMs, bucket.totalRequests > 0 {
            summary.weightedLatencyTotal += latency * bucket.totalRequests
            summary.latencyWeight += bucket.totalRequests
        }
        if let ttft = bucket.avgTtftMs, bucket.totalRequests > 0 {
            summary.weightedTtftTotal += ttft * bucket.totalRequests
            summary.ttftWeight += bucket.totalRequests
        }
    }
    return summary
}

private func trendPoints(_ buckets: [UsageAggregateBucket], range: UsageTimeRange) -> [UsageTrendPoint] {
    buckets
        .compactMap { bucket -> UsageTrendPoint? in
            guard let bucketStartMs = bucket.bucketStartMs else { return nil }
            return UsageTrendPoint(
                bucketStartMs: bucketStartMs,
                label: trendLabel(bucketStartMs, range: range),
                requests: bucket.totalRequests,
                failures: bucket.failureCount,
                tokens: bucket.totalTokens
            )
        }
        .sorted { $0.bucketStartMs < $1.bucketStartMs }
        .suffix(30)
        .map { $0 }
}

private func trendLabel(_ bucketStartMs: Int, range: UsageTimeRange) -> String {
    let date = Date(timeIntervalSince1970: TimeInterval(bucketStartMs) / 1_000)
    let formatter = DateFormatter()
    formatter.dateFormat = range == .today ? "HH:00" : "M/d"
    return formatter.string(from: date)
}

private func bucketStartMs(timestampSeconds: Int, range: UsageTimeRange) -> Int {
    let date = Date(timeIntervalSince1970: TimeInterval(timestampSeconds))
    let calendar = Calendar.current
    let bucketDate: Date
    if range == .today {
        let comps = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        bucketDate = calendar.date(from: comps) ?? date
    } else {
        bucketDate = calendar.startOfDay(for: date)
    }
    return Int(bucketDate.timeIntervalSince1970 * 1_000)
}

private func rankBuckets(_ buckets: [UsageAggregateBucket], label: (UsageAggregateBucket) -> String?) -> [UsageRankingRow] {
    var rowsByLabel: [String: UsageRankingRow] = [:]
    for bucket in buckets {
        let value = label(bucket) ?? ""
        let rowLabel = value.ifEmpty("-")
        let previous = rowsByLabel[rowLabel] ?? UsageRankingRow(label: rowLabel, requests: 0, failures: 0, tokens: 0)
        rowsByLabel[rowLabel] = UsageRankingRow(
            label: rowLabel,
            requests: previous.requests + bucket.totalRequests,
            failures: previous.failures + bucket.failureCount,
            tokens: previous.tokens + bucket.totalTokens
        )
    }
    return Array(rowsByLabel.values).sortedForRanking().prefix(3).map { $0 }
}

private func aggregateSnapshot(from snapshots: [UsageSnapshot], range: UsageTimeRange) -> UsageSnapshot {
    var scope = UsageScope()
    var recent = UsageScope()
    var trendByBucket: [Int: UsageTrendPoint] = [:]
    var modelRows: [String: UsageRankingRow] = [:]
    var apiKeyRows: [String: UsageRankingRow] = [:]
    var refreshedAt = Date()

    for snapshot in snapshots {
        scope.add(snapshot.scope)
        recent.add(snapshot.recent)
        refreshedAt = min(refreshedAt, snapshot.refreshedAt)

        for point in snapshot.trendPoints {
            let previous = trendByBucket[point.bucketStartMs] ?? UsageTrendPoint(
                bucketStartMs: point.bucketStartMs,
                label: point.label,
                requests: 0,
                failures: 0,
                tokens: 0
            )
            trendByBucket[point.bucketStartMs] = UsageTrendPoint(
                bucketStartMs: point.bucketStartMs,
                label: previous.label,
                requests: previous.requests + point.requests,
                failures: previous.failures + point.failures,
                tokens: previous.tokens + point.tokens
            )
        }

        mergeRankingRows(snapshot.topModels, prefix: snapshot.sourceName, into: &modelRows)
        mergeRankingRows(snapshot.topApiKeys, prefix: snapshot.sourceName, into: &apiKeyRows)
    }

    return UsageSnapshot(
        sourceID: UsageDashboardSnapshot.aggregateSourceID,
        sourceName: snapshots.count > 1 ? "All Adapters" : (snapshots.first?.sourceName ?? "All Adapters"),
        platform: snapshots.first?.platform ?? .cliproxyapiPro,
        selectedRange: range,
        scope: scope,
        recent: recent,
        trendPoints: trendByBucket.values.sorted { $0.bucketStartMs < $1.bucketStartMs }.suffix(30).map { $0 },
        topModels: Array(modelRows.values).sortedForRanking().prefix(3).map { $0 },
        topApiKeys: Array(apiKeyRows.values).sortedForRanking().prefix(3).map { $0 },
        refreshedAt: refreshedAt
    )
}

private func mergeRankingRows(_ rows: [UsageRankingRow], prefix: String, into target: inout [String: UsageRankingRow]) {
    for row in rows {
        let label = "\(prefix) · \(row.label)"
        let previous = target[label] ?? UsageRankingRow(label: label, requests: 0, failures: 0, tokens: 0)
        target[label] = UsageRankingRow(
            label: label,
            requests: previous.requests + row.requests,
            failures: previous.failures + row.failures,
            tokens: previous.tokens + row.tokens
        )
    }
}

private func maskHashRow(_ row: UsageRankingRow) -> UsageRankingRow {
    UsageRankingRow(label: maskHash(row.label), requests: row.requests, failures: row.failures, tokens: row.tokens)
}

private func maskHash(_ value: String) -> String {
    if value == "-" || value.count <= 12 { return value }
    return "\(value.prefix(6))...\(value.suffix(6))"
}

private func parseSub2APIDateMs(_ value: String) -> Int {
    let formats = ["yyyy-MM-dd HH:00", "yyyy-MM-dd HH", "yyyy-MM-dd"]
    for format in formats {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        if let date = formatter.date(from: value) {
            return Int(date.timeIntervalSince1970 * 1_000)
        }
    }
    return 0
}

private struct Sub2APIEnvelope<T: Decodable>: Decodable {
    var code: Int
    var message: String
    var data: T
}

private struct Sub2APIStats: Decodable {
    var totalRequests: Int
    var totalInputTokens: Int
    var totalOutputTokens: Int
    var totalCacheCreationTokens: Int
    var totalCacheReadTokens: Int
    var totalTokens: Int
    var todayRequests: Int
    var todayInputTokens: Int
    var todayOutputTokens: Int
    var todayCacheCreationTokens: Int
    var todayCacheReadTokens: Int
    var todayTokens: Int
    var averageDurationMs: Double
    var rpm: Int
    var tpm: Int

    func scope(for range: UsageTimeRange) -> UsageScope {
        let useToday = range == .today
        var scope = UsageScope()
        scope.totalRequests = useToday ? todayRequests : totalRequests
        scope.successCount = scope.totalRequests
        scope.inputTokens = useToday ? todayInputTokens : totalInputTokens
        scope.outputTokens = useToday ? todayOutputTokens : totalOutputTokens
        scope.cacheTokens = useToday ? todayCacheReadTokens + todayCacheCreationTokens : totalCacheReadTokens + totalCacheCreationTokens
        scope.totalTokens = useToday ? todayTokens : totalTokens
        if averageDurationMs > 0 && scope.totalRequests > 0 {
            scope.weightedLatencyTotal = Int(averageDurationMs.rounded()) * scope.totalRequests
            scope.latencyWeight = scope.totalRequests
        }
        return scope
    }

    func recentScope() -> UsageScope {
        var scope = UsageScope()
        scope.totalRequests = rpm
        scope.successCount = rpm
        scope.totalTokens = tpm
        return scope
    }
}

private struct Sub2APITrendPayload: Decodable {
    var trend: [Sub2APITrendPoint]
}

private struct Sub2APITrendPoint: Decodable {
    var date: String
    var requests: Int
    var inputTokens: Int
    var outputTokens: Int
    var cacheCreationTokens: Int
    var cacheReadTokens: Int
    var totalTokens: Int
}

private struct Sub2APIModelsPayload: Decodable {
    var models: [Sub2APIModelStat]
}

private struct Sub2APIModelStat: Decodable {
    var model: String
    var requests: Int
    var totalTokens: Int
}

private struct Sub2APIAPIKeyTrendPayload: Decodable {
    var trend: [Sub2APIAPIKeyTrendPoint]
}

private struct Sub2APIAPIKeyTrendPoint: Decodable {
    var apiKeyId: Int
    var keyName: String
    var requests: Int
    var tokens: Int
}

private struct NewAPIEnvelope<T: Decodable>: Decodable {
    var success: Bool
    var message: String?
    var data: T
}

private struct NewAPIStat: Decodable {
    var quota: Double?
    var rpm: Int
    var tpm: Int
}

private struct NewAPILogPage: Decodable {
    var items: [NewAPILog]
}

private struct NewAPILog: Decodable {
    var createdAt: Int
    var type: Int
    var tokenName: String
    var modelName: String
    var promptTokens: Int
    var completionTokens: Int
    var useTime: Int
}

private extension Array where Element == UsageRankingRow {
    func sortedForRanking() -> [UsageRankingRow] {
        sorted { $0.requests == $1.requests ? $0.tokens > $1.tokens : $0.requests > $1.requests }
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}
