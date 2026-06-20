import AppKit
import Foundation

func configSummary(_ config: AppConfig) -> String {
    let host = URL(string: config.baseURL)?.host ?? "-"
    return "host=\(host) language=\(config.resolvedLanguage.rawValue) titleMetric=\(config.resolvedTitleMetric.rawValue) timeRange=\(config.resolvedTimeRange.rawValue) listItems=\(config.resolvedListItems.map { $0.rawValue }.joined(separator: ",")) interval=\(config.refreshInterval)"
}
