import Foundation

struct AppConfig: Codable {
    var adapters: [AdapterConfig]
    var platform: MonitorPlatform?
    var baseURL: String
    var managementKey: String
    var authHeaderName: String?
    var newApiUserID: Int?
    var refreshIntervalSeconds: TimeInterval?
    var display: String?
    var monitoringPath: String?
    var language: AppLanguage?
    var titleMetric: DisplayMetric?
    var listItems: [DisplayItem]?
    var timeRange: UsageTimeRange?
    var activityPeriod: UsageActivityPeriod?
    var activityStartDate: Date?
    var activityEndDate: Date?

    static let defaultConfig = AppConfig(
        adapters: [
            AdapterConfig(
                id: "primary",
                name: "Relay Meter",
                enabled: true,
                platform: .cliproxyapiPro,
                baseURL: "https://relay.example.com",
                managementKey: "replace-with-management-key",
                authHeaderName: MonitorPlatform.cliproxyapiPro.defaultAuthHeaderName,
                newApiUserID: nil,
                monitoringPath: MonitorPlatform.cliproxyapiPro.defaultMonitoringPath
            )
        ],
        platform: .cliproxyapiPro,
        baseURL: "https://relay.example.com",
        managementKey: "replace-with-management-key",
        authHeaderName: MonitorPlatform.cliproxyapiPro.defaultAuthHeaderName,
        newApiUserID: nil,
        refreshIntervalSeconds: 30,
        display: DisplayMetric.requests.rawValue,
        monitoringPath: "/management.html#/monitoring",
        language: .english,
        titleMetric: .requests,
        listItems: DisplayItem.defaultItems,
        timeRange: .today,
        activityPeriod: .lastYear,
        activityStartDate: nil,
        activityEndDate: nil
    )

    var refreshInterval: TimeInterval {
        max(refreshIntervalSeconds ?? 30, 10)
    }

    var resolvedLanguage: AppLanguage {
        language ?? .english
    }

    var resolvedTitleMetric: DisplayMetric {
        titleMetric ?? DisplayMetric(rawValue: display ?? "") ?? .requests
    }

    var resolvedListItems: [DisplayItem] {
        let values = listItems ?? DisplayItem.defaultItems
        let supported = values.filter { $0 != .topApiKey }
        let resolved = supported.isEmpty ? DisplayItem.defaultItems : supported
        if activityPeriod == nil, !resolved.contains(.activity) {
            return resolved + [.activity]
        }
        return resolved
    }

    var resolvedTimeRange: UsageTimeRange {
        timeRange ?? .today
    }

    var resolvedActivityPeriod: UsageActivityPeriod {
        .lastYear
    }

    func activityBounds(reference: Date = Date(), calendar: Calendar = .current) -> UsageDateBounds? {
        UsageActivityPeriod.lastYear.bounds(
            reference: reference,
            calendar: calendar,
            customStart: nil,
            customEnd: nil
        )
    }

    var resolvedAdapters: [AdapterConfig] {
        adapters.filter { $0.isEnabled }
    }

    var primaryAdapter: AdapterConfig {
        resolvedAdapters.first ?? AppConfig.defaultConfig.adapters[0]
    }

    var resolvedPlatform: MonitorPlatform {
        primaryAdapter.platform
    }

    var resolvedAuthHeaderName: String {
        primaryAdapter.resolvedAuthHeaderName
    }

    func monitoringURLs(for sourceID: String) -> [URL] {
        if sourceID == UsageDashboardSnapshot.aggregateSourceID {
            return resolvedAdapters.compactMap(\.monitoringURL)
        }
        return resolvedAdapters
            .filter { $0.resolvedID == sourceID }
            .compactMap(\.monitoringURL)
    }

    func scoped(to adapter: AdapterConfig) -> AppConfig {
        var scoped = self
        scoped.adapters = [adapter]
        scoped.platform = adapter.platform
        scoped.baseURL = adapter.baseURL
        scoped.managementKey = adapter.managementKey
        scoped.authHeaderName = adapter.authHeaderName
        scoped.newApiUserID = adapter.newApiUserID
        scoped.monitoringPath = adapter.monitoringPath
        return scoped
    }
}

struct AdapterConfig: Codable {
    var id: String?
    var name: String?
    var enabled: Bool?
    var platform: MonitorPlatform
    var baseURL: String
    var managementKey: String
    var authHeaderName: String?
    var newApiUserID: Int?
    var monitoringPath: String?

    var isEnabled: Bool {
        enabled ?? true
    }

    var resolvedID: String {
        let explicit = id?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let explicit, !explicit.isEmpty { return explicit }
        return "\(platform.rawValue)-\(baseURL)"
    }

    var displayName: String {
        let explicit = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let explicit, !explicit.isEmpty { return explicit }
        return platform.displayName
    }

    var resolvedAuthHeaderName: String {
        let explicit = authHeaderName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let explicit, !explicit.isEmpty { return explicit }
        return platform.defaultAuthHeaderName
    }

    var monitoringURL: URL? {
        let trimmed = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let path = monitoringPath ?? platform.defaultMonitoringPath
        return URL(string: trimmed + path)
    }
}

enum MonitorPlatform: String, Codable, CaseIterable {
    case cliproxyapiPro
    case sub2api
    case newApi

    var displayName: String {
        switch self {
        case .cliproxyapiPro: return "CLIProxyAPI-Pro"
        case .sub2api: return "sub2api"
        case .newApi: return "new-api"
        }
    }

    var defaultAuthHeaderName: String {
        switch self {
        case .cliproxyapiPro: return "Authorization"
        case .sub2api: return "x-api-key"
        case .newApi: return "Authorization"
        }
    }

    var defaultMonitoringPath: String {
        switch self {
        case .cliproxyapiPro: return "/management.html#/monitoring"
        case .sub2api: return "/admin/dashboard"
        case .newApi: return "/"
        }
    }
}

enum AppLanguage: String, Codable, CaseIterable {
    case english = "en"
    case chinese = "zh-Hans"
}

enum UsageTimeRange: String, Codable, CaseIterable {
    case today
    case sevenDays = "7d"
    case thirtyDays = "30d"
    case all

    func label(texts: TextBundle) -> String {
        switch self {
        case .today: return texts.rangeToday
        case .sevenDays: return texts.range7d
        case .thirtyDays: return texts.range30d
        case .all: return texts.rangeAll
        }
    }
}

enum DisplayMetric: String, Codable, CaseIterable {
    case requests
    case tokens
    case failures
    case successRate
    case latency
    case cache
    case recent
    case cost
}

enum DisplayItem: String, Codable, CaseIterable {
    case traffic
    case successRate
    case tokens
    case cache
    case latency
    case recent
    case trend
    case activity
    case topModel
    case topApiKey
    case refreshedAt

    static let configurableItems = allCases.filter { $0 != .topApiKey }

    static let defaultItems: [DisplayItem] = [
        .traffic,
        .successRate,
        .tokens,
        .latency,
        .recent,
        .trend,
        .activity,
        .topModel,
        .refreshedAt
    ]
}

struct AggregateResponse: Decodable {
    var items: [UsageAggregateBucket]
}

struct UsageAggregateBucket: Decodable {
    var bucketStartMs: Int?
    var provider: String?
    var model: String?
    var apiKeyHash: String?
    var totalRequests: Int
    var successCount: Int
    var failureCount: Int
    var totalTokens: Int
    var inputTokens: Int?
    var outputTokens: Int?
    var reasoningTokens: Int?
    var cacheTokens: Int?
    var avgLatencyMs: Int?
    var avgTtftMs: Int?
    var estimatedCost: Double?
}

struct UsageScope: Codable {
    var totalRequests = 0
    var successCount = 0
    var failureCount = 0
    var totalTokens = 0
    var inputTokens = 0
    var outputTokens = 0
    var reasoningTokens = 0
    var cacheTokens = 0
    var costUSD: Double?
    var costIsEstimated = false
    var weightedLatencyTotal = 0
    var latencyWeight = 0
    var weightedTtftTotal = 0
    var ttftWeight = 0

    var successRate: Double {
        guard totalRequests > 0 else { return 1 }
        return Double(successCount) / Double(totalRequests)
    }

    var avgLatencyMs: Int? {
        guard latencyWeight > 0 else { return nil }
        return weightedLatencyTotal / latencyWeight
    }

    var avgTtftMs: Int? {
        guard ttftWeight > 0 else { return nil }
        return weightedTtftTotal / ttftWeight
    }

    var cacheRate: Double {
        guard inputTokens > 0 else { return 0 }
        return Double(cacheTokens) / Double(inputTokens)
    }

    mutating func add(_ other: UsageScope) {
        totalRequests += other.totalRequests
        successCount += other.successCount
        failureCount += other.failureCount
        totalTokens += other.totalTokens
        inputTokens += other.inputTokens
        outputTokens += other.outputTokens
        reasoningTokens += other.reasoningTokens
        cacheTokens += other.cacheTokens
        weightedLatencyTotal += other.weightedLatencyTotal
        latencyWeight += other.latencyWeight
        weightedTtftTotal += other.weightedTtftTotal
        ttftWeight += other.ttftWeight
    }
}

enum UsageCost {
    static func totalIfComplete(_ values: [Double?]) -> Double? {
        guard !values.isEmpty, values.allSatisfy({ $0 != nil }) else { return nil }
        return values.compactMap { $0 }.reduce(0, +)
    }

    static func totalIfComplete(_ scopes: [UsageScope], expectedCount: Int) -> (value: Double, isEstimated: Bool)? {
        guard scopes.count == expectedCount else { return nil }
        guard let value = totalIfComplete(scopes.map(\.costUSD)) else { return nil }
        return (value, scopes.contains(where: \.costIsEstimated))
    }
}

struct UsageRankingRow: Codable {
    var label: String
    var requests: Int
    var failures: Int
    var tokens: Int
    var successRate: Double {
        guard requests > 0 else { return 1 }
        return Double(requests - failures) / Double(requests)
    }

    mutating func add(requests: Int, failures: Int, tokens: Int) {
        self.requests += requests
        self.failures += failures
        self.tokens += tokens
    }
}

struct UsageTrendPoint: Codable {
    var bucketStartMs: Int
    var label: String
    var requests: Int
    var failures: Int
    var tokens: Int

    mutating func add(requests: Int, failures: Int, tokens: Int) {
        self.requests += requests
        self.failures += failures
        self.tokens += tokens
    }
}

struct NewAPIActivityRow: Decodable {
    var createdAt: Int
    var count: Int
    var tokenUsed: Int
}

enum UsageActivityDayState: Codable, Equatable {
    case observed
    case knownZero
    case partial
    case unknown
}

enum UsageActivityAvailability: Codable, Equatable {
    case complete
    case partial
    case unavailable
}

enum UsageActivityUnavailableReason: Codable, Equatable {
    case dataExportDisabled
    case requestFailed
}

struct UsageActivityDay: Codable, Equatable {
    let start: Date
    var requests: Int
    var failures: Int
    var tokens: Int
    var state: UsageActivityDayState
}

struct UsageActivityDataset: Codable {
    let bounds: UsageDateBounds
    var days: [UsageActivityDay]
    var availability: UsageActivityAvailability
    var unavailableReason: UsageActivityUnavailableReason?
}

struct UsageSnapshot: Codable {
    var sourceID: String
    var sourceName: String
    var platform: MonitorPlatform
    var selectedRange: UsageTimeRange
    var scope: UsageScope
    var recent: UsageScope
    var trendPoints: [UsageTrendPoint]
    var activity: UsageActivityDataset
    var topModels: [UsageRankingRow]
    var topApiKeys: [UsageRankingRow]
    var refreshedAt: Date

    var health: HealthState {
        let recentFailureRate = recent.totalRequests > 0 ? Double(recent.failureCount) / Double(recent.totalRequests) : 0
        if recent.failureCount >= 3 && recentFailureRate >= 0.05 { return .bad }
        if scope.totalRequests >= 20 && scope.successRate < 0.95 { return .bad }
        if recent.failureCount > 0 { return .warn }
        if scope.totalRequests >= 20 && scope.successRate < 0.99 { return .warn }
        if scope.totalRequests == 0 && recent.totalRequests == 0 { return .idle }
        return .good
    }
}

struct AdapterSnapshotError: Codable {
    var adapterName: String
    var message: String
}

struct UsageDashboardSnapshot: Codable {
    static let aggregateSourceID = "all"
    var selectedRange: UsageTimeRange
    var aggregate: UsageSnapshot
    var adapters: [UsageSnapshot]
    var errors: [AdapterSnapshotError]
    var refreshedAt: Date

    var health: HealthState {
        if !errors.isEmpty { return adapters.isEmpty ? .bad : .warn }
        return aggregate.health
    }
}

enum HealthState {
    case good
    case idle
    case warn
    case bad

    var label: String {
        label(language: .english)
    }

    func label(language: AppLanguage) -> String {
        let texts = TextBundle.forLanguage(language)
        switch self {
        case .good: return texts.healthGood
        case .idle: return texts.healthIdle
        case .warn: return texts.healthWarn
        case .bad: return texts.healthBad
        }
    }
}

enum MonitorError: LocalizedError {
    case missingConfig(URL)
    case invalidBaseURL(String)
    case invalidStatus(Int, String)
    case invalidResponse
    case unsupportedPlatform(MonitorPlatform)
    case noAdaptersConfigured
    case allAdaptersFailed(String)
    case invalidActivityDateRange

    var errorDescription: String? {
        switch self {
        case .missingConfig(let url):
            return "Missing config: \(url.path)"
        case .invalidBaseURL(let value):
            return "Invalid baseURL: \(value)"
        case .invalidStatus(let status, let body):
            let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "HTTP \(status)" : "HTTP \(status): \(trimmed)"
        case .invalidResponse:
            return "Invalid server response"
        case .unsupportedPlatform(let platform):
            return "Unsupported platform: \(platform.displayName)"
        case .noAdaptersConfigured:
            return "No adapters configured"
        case .allAdaptersFailed(let message):
            return "All adapters failed: \(message)"
        case .invalidActivityDateRange:
            return "Invalid activity date range"
        }
    }
}
