import AppKit
import Foundation

func configSummary(_ config: AppConfig) -> String {
    let adapters = config.resolvedAdapters
    let hosts = adapters.map { URL(string: $0.baseURL)?.host ?? "-" }.joined(separator: ",")
    let platforms = adapters.map { $0.platform.rawValue }.joined(separator: ",")
    return "adapters=\(adapters.count) platforms=\(platforms) hosts=\(hosts) language=\(config.resolvedLanguage.rawValue) titleMetric=\(config.resolvedTitleMetric.rawValue) timeRange=\(config.resolvedTimeRange.rawValue) listItems=\(config.resolvedListItems.map { $0.rawValue }.joined(separator: ",")) interval=\(config.refreshInterval)"
}
