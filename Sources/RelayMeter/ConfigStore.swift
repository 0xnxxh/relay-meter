import Foundation

final class ConfigStore {
    let url: URL

    init(
        url: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/relay-meter/config.json")
    ) {
        self.url = url
    }

    func load() throws -> AppConfig {
        guard FileManager.default.fileExists(atPath: url.path) else {
            let config = AppConfig.defaultConfig
            try save(config)
            return config
        }
        let data = try Data(contentsOf: url)
        let config = try JSONDecoder().decode(AppConfig.self, from: data)
        for adapter in config.resolvedAdapters {
            guard URL(string: adapter.baseURL) != nil else {
                throw MonitorError.invalidBaseURL(adapter.baseURL)
            }
        }
        return config
    }

    func save(_ config: AppConfig) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(config).write(to: url, options: .atomic)
    }
}
