import Foundation

/// One ring in the edge dock: a single adapter and its share of the dashboard's token volume.
struct DockGaugeItem {
    let sourceID: String
    let name: String
    let platform: MonitorPlatform
    /// 0...1 share of the total tokens across all adapters in the snapshot.
    let share: Double
    let scope: UsageScope
    let topModels: [UsageRankingRow]
}

enum SidebarDockModel {
    /// Builds one gauge per adapter, sorted by descending share so the dock order is stable and meaningful.
    ///
    /// When the snapshot has no tokens at all there is no honest denominator, so every share is `0`
    /// rather than an invented even split; the ring view renders that as an explicit empty state.
    static func dockItems(from dashboard: UsageDashboardSnapshot) -> [DockGaugeItem] {
        let total = dashboard.adapters.reduce(0) { $0 + max($1.scope.totalTokens, 0) }
        return dashboard.adapters
            .map { snapshot in
                DockGaugeItem(
                    sourceID: snapshot.sourceID,
                    name: snapshot.sourceName,
                    platform: snapshot.platform,
                    share: total > 0 ? Double(max(snapshot.scope.totalTokens, 0)) / Double(total) : 0,
                    scope: snapshot.scope,
                    topModels: snapshot.topModels
                )
            }
            .sorted { lhs, rhs in
                if lhs.share != rhs.share { return lhs.share > rhs.share }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    /// Model share inside a single adapter, used by the bubble rows.
    static func modelShares(in item: DockGaugeItem) -> [(row: UsageRankingRow, share: Double)] {
        let total = item.topModels.reduce(0) { $0 + max($1.tokens, 0) }
        return item.topModels.map { row in
            (row, total > 0 ? Double(max(row.tokens, 0)) / Double(total) : 0)
        }
    }
}
