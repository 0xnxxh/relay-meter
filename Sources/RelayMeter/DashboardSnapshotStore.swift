import Foundation
import CryptoKit

final class DashboardSnapshotStore {
    let url: URL

    init(
        url: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/relay-meter/dashboard.json")
    ) {
        self.url = url
    }

    func load(for config: AppConfig) -> UsageDashboardSnapshot? {
        guard let data = try? Data(contentsOf: url),
              let cached = try? JSONDecoder().decode(CachedDashboard.self, from: data),
              cached.configuration == configurationKey(for: config) else {
            return nil
        }
        return cached.snapshot
    }

    func save(_ snapshot: UsageDashboardSnapshot, for config: AppConfig) throws {
        guard snapshot.errors.isEmpty else { return }
        let cached = CachedDashboard(
            configuration: configurationKey(for: config),
            snapshot: snapshot
        )
        let data = try JSONEncoder().encode(cached)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: url.path
        )
    }

    private func configurationKey(for config: AppConfig) -> ConfigurationKey {
        ConfigurationKey(
            adapters: config.resolvedAdapters.map {
                AdapterKey(
                    id: $0.resolvedID,
                    platform: $0.platform,
                    baseURL: $0.baseURL,
                    newApiUserID: $0.newApiUserID,
                    credentialFingerprint: SHA256.hash(data: Data($0.managementKey.utf8))
                        .map { String(format: "%02x", $0) }
                        .joined()
                )
            },
            timeRange: config.resolvedTimeRange
        )
    }
}

private struct CachedDashboard: Codable {
    let configuration: ConfigurationKey
    let snapshot: UsageDashboardSnapshot
}

private struct ConfigurationKey: Codable, Equatable {
    let adapters: [AdapterKey]
    let timeRange: UsageTimeRange
}

private struct AdapterKey: Codable, Equatable {
    let id: String
    let platform: MonitorPlatform
    let baseURL: String
    let newApiUserID: Int?
    let credentialFingerprint: String
}
