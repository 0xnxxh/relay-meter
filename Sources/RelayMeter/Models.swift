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
        timeRange: .today
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
        return values.isEmpty ? DisplayItem.defaultItems : values
    }

    var resolvedTimeRange: UsageTimeRange {
        timeRange ?? .today
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

    var monitoringURL: URL? {
        primaryAdapter.monitoringURL
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
}

enum DisplayItem: String, Codable, CaseIterable {
    case traffic
    case successRate
    case tokens
    case cache
    case latency
    case recent
    case trend
    case topModel
    case topApiKey
    case refreshedAt

    static let defaultItems: [DisplayItem] = [
        .traffic,
        .successRate,
        .tokens,
        .latency,
        .recent,
        .trend,
        .topModel,
        .topApiKey,
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
}

struct UsageScope {
    var totalRequests = 0
    var successCount = 0
    var failureCount = 0
    var totalTokens = 0
    var inputTokens = 0
    var outputTokens = 0
    var reasoningTokens = 0
    var cacheTokens = 0
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

struct UsageRankingRow {
    var label: String
    var requests: Int
    var failures: Int
    var tokens: Int
    var successRate: Double {
        guard requests > 0 else { return 1 }
        return Double(requests - failures) / Double(requests)
    }
}

struct UsageTrendPoint {
    var bucketStartMs: Int
    var label: String
    var requests: Int
    var failures: Int
    var tokens: Int
}

struct UsageSnapshot {
    var sourceID: String
    var sourceName: String
    var platform: MonitorPlatform
    var selectedRange: UsageTimeRange
    var scope: UsageScope
    var recent: UsageScope
    var trendPoints: [UsageTrendPoint]
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

struct AdapterSnapshotError {
    var adapterName: String
    var message: String
}

struct UsageDashboardSnapshot {
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
        }
    }
}
