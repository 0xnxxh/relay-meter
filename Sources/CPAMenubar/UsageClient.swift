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
        logger.info("snapshot buckets range=\(range.rawValue) interval=\(interval) today=\(todayBuckets.count) recent=\(recentBuckets.count) models=\(modelBuckets.count) apiKeys=\(apiKeyBuckets.count)")
        return UsageSnapshot(
            selectedRange: range,
            scope: summarize(todayBuckets),
            recent: summarize(recentBuckets),
            trendPoints: trendPoints(todayBuckets, range: range),
            topModels: rank(modelBuckets, label: \.model),
            topApiKeys: rank(apiKeyBuckets, label: \.apiKeyHash).map(maskHashRow),
            refreshedAt: Date()
        )
    }

    private func fetchScope(
        fromMs: Int,
        interval: String = "hour",
        limit: Int? = nil,
        groupBy: [String]
    ) async throws -> [UsageAggregateBucket] {
        guard var components = URLComponents(url: usageURL(path: "aggregates"), resolvingAgainstBaseURL: false) else {
            throw MonitorError.invalidBaseURL(config.baseURL)
        }

        var queryItems = [
            URLQueryItem(name: "from_ms", value: String(fromMs)),
            URLQueryItem(name: "to_ms", value: String(Int(Date().timeIntervalSince1970 * 1000))),
            URLQueryItem(name: "interval", value: interval),
            URLQueryItem(name: "limit", value: String(limit ?? (groupBy.isEmpty ? 48 : 200)))
        ]
        if !groupBy.isEmpty {
            queryItems.append(URLQueryItem(name: "group_by", value: groupBy.joined(separator: ",")))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw MonitorError.invalidBaseURL(config.baseURL)
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(config.managementKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        logger.info("GET /usage/aggregates groupBy=\(groupBy.joined(separator: ",").ifEmpty("-")) interval=\(interval) fromMs=\(fromMs)")
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MonitorError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            logger.error("aggregates status=\(httpResponse.statusCode) body=\(body.prefix(200))")
            throw MonitorError.invalidStatus(httpResponse.statusCode, body)
        }

        let items = try JSONDecoder().decode(AggregateResponse.self, from: data).items
        logger.info("aggregates ok groupBy=\(groupBy.joined(separator: ",").ifEmpty("-")) items=\(items.count)")
        return items
    }

    private func usageURL(path: String) -> URL {
        let trimmed = config.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if trimmed.hasSuffix("/v0/management") {
            return URL(string: "\(trimmed)/usage/\(path)")!
        }
        if trimmed.hasSuffix("/v0") {
            return URL(string: "\(trimmed)/management/usage/\(path)")!
        }
        return URL(string: "\(trimmed)/v0/management/usage/\(path)")!
    }

    private func startOfTodayMs() -> Int {
        let start = Calendar.current.startOfDay(for: Date())
        return Int(start.timeIntervalSince1970 * 1000)
    }

    private func rangeStartMs(_ range: UsageTimeRange) -> Int {
        let todayStart = startOfTodayMs()
        let dayMs = 24 * 60 * 60 * 1000
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

    private func aggregateInterval(_ range: UsageTimeRange) -> String {
        range == .today ? "hour" : "day"
    }

    private func aggregateLimit(_ range: UsageTimeRange) -> Int {
        switch range {
        case .today: return 48
        case .sevenDays: return 100
        case .thirtyDays: return 400
        case .all: return 2000
        }
    }

    private func minutesAgoMs(_ minutes: Int) -> Int {
        Int(Date().addingTimeInterval(TimeInterval(-minutes * 60)).timeIntervalSince1970 * 1000)
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
        let date = Date(timeIntervalSince1970: TimeInterval(bucketStartMs) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = range == .today ? "HH:00" : "M/d"
        return formatter.string(from: date)
    }

    private func rank(_ buckets: [UsageAggregateBucket], label: (UsageAggregateBucket) -> String?) -> [UsageRankingRow] {
        var rowsByLabel: [String: UsageRankingRow] = [:]
        for bucket in buckets {
            let rowLabel = label(bucket)?.isEmpty == false ? label(bucket)! : "-"
            let previous = rowsByLabel[rowLabel] ?? UsageRankingRow(label: rowLabel, requests: 0, failures: 0, tokens: 0)
            rowsByLabel[rowLabel] = UsageRankingRow(
                label: rowLabel,
                requests: previous.requests + bucket.totalRequests,
                failures: previous.failures + bucket.failureCount,
                tokens: previous.tokens + bucket.totalTokens
            )
        }

        return rowsByLabel.values
        .sorted { $0.requests == $1.requests ? $0.tokens > $1.tokens : $0.requests > $1.requests }
        .prefix(3)
        .map { $0 }
    }

    private func maskHashRow(_ row: UsageRankingRow) -> UsageRankingRow {
        UsageRankingRow(label: maskHash(row.label), requests: row.requests, failures: row.failures, tokens: row.tokens)
    }

    private func maskHash(_ value: String) -> String {
        if value == "-" || value.count <= 12 { return value }
        return "\(value.prefix(6))...\(value.suffix(6))"
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}
