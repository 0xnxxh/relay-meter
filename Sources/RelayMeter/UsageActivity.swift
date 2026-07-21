import Foundation

struct UsageDateBounds: Equatable {
    let start: Date
    let end: Date
}

enum UsageActivityPeriod: String, Codable, CaseIterable {
    case today
    case thisWeek
    case thisMonth
    case thisYear
    case last7Days
    case last30Days
    case lastYear
    case custom

    func bounds(
        reference: Date = Date(),
        calendar: Calendar = .current,
        customStart: Date? = nil,
        customEnd: Date? = nil
    ) -> UsageDateBounds? {
        let today = calendar.startOfDay(for: reference)
        let start: Date

        switch self {
        case .today:
            start = today
        case .thisWeek:
            let weekday = calendar.component(.weekday, from: today)
            let daysSinceMonday = (weekday + 5) % 7
            guard let value = calendar.date(byAdding: .day, value: -daysSinceMonday, to: today) else { return nil }
            start = value
        case .thisMonth:
            guard let value = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) else { return nil }
            start = value
        case .thisYear:
            guard let value = calendar.date(from: calendar.dateComponents([.year], from: today)) else { return nil }
            start = value
        case .last7Days:
            guard let value = calendar.date(byAdding: .day, value: -6, to: today) else { return nil }
            start = value
        case .last30Days:
            guard let value = calendar.date(byAdding: .day, value: -29, to: today) else { return nil }
            start = value
        case .lastYear:
            guard let value = calendar.date(byAdding: .year, value: -1, to: today) else { return nil }
            start = value
        case .custom:
            guard let customStart, let customEnd else { return nil }
            let normalizedStart = calendar.startOfDay(for: customStart)
            let normalizedEnd = calendar.startOfDay(for: customEnd)
            guard normalizedStart <= normalizedEnd,
                  let dayAfterEnd = calendar.date(byAdding: .day, value: 1, to: normalizedEnd),
                  let inclusiveEnd = calendar.date(byAdding: .second, value: -1, to: dayAfterEnd) else { return nil }
            return UsageDateBounds(start: normalizedStart, end: inclusiveEnd)
        }

        return UsageDateBounds(start: start, end: reference)
    }
}

enum UsageActivityGranularity: String, CaseIterable {
    case daily
    case weekly
    case monthly
    case cumulative
}

struct UsageActivityBucket {
    let start: Date
    var requests: Int
    var failures: Int
    var tokens: Int
}

enum UsageActivitySeries {
    static func aggregate(
        _ points: [UsageTrendPoint],
        granularity: UsageActivityGranularity,
        calendar: Calendar = .current
    ) -> [UsageActivityBucket] {
        if granularity == .cumulative {
            var requests = 0
            var failures = 0
            var tokens = 0
            return aggregate(points, granularity: .daily, calendar: calendar).map { bucket in
                requests += bucket.requests
                failures += bucket.failures
                tokens += bucket.tokens
                return UsageActivityBucket(start: bucket.start, requests: requests, failures: failures, tokens: tokens)
            }
        }

        var buckets: [Date: UsageActivityBucket] = [:]
        for point in points {
            let date = Date(timeIntervalSince1970: TimeInterval(point.bucketStartMs) / 1_000)
            guard let bucketStart = bucketStart(for: date, granularity: granularity, calendar: calendar) else { continue }
            var bucket = buckets[bucketStart] ?? UsageActivityBucket(start: bucketStart, requests: 0, failures: 0, tokens: 0)
            bucket.requests += point.requests
            bucket.failures += point.failures
            bucket.tokens += point.tokens
            buckets[bucketStart] = bucket
        }
        return buckets.values.sorted { $0.start < $1.start }
    }

    static func intensity(value: Int, maximum: Int) -> Int {
        guard value > 0, maximum > 0 else { return 0 }
        return min(4, max(1, Int(ceil(Double(value) / Double(maximum) * 4))))
    }

    private static func bucketStart(
        for date: Date,
        granularity: UsageActivityGranularity,
        calendar: Calendar
    ) -> Date? {
        switch granularity {
        case .daily, .cumulative:
            return calendar.startOfDay(for: date)
        case .weekly:
            let day = calendar.startOfDay(for: date)
            let weekday = calendar.component(.weekday, from: day)
            return calendar.date(byAdding: .day, value: -((weekday + 5) % 7), to: day)
        case .monthly:
            return calendar.date(from: calendar.dateComponents([.year, .month], from: date))
        }
    }
}
