import Foundation

struct UsageDateBounds: Codable, Equatable {
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

extension UsageActivityDataset {
    func clipped(to requestedBounds: UsageDateBounds, calendar: Calendar = .current) -> UsageActivityDataset {
        let start = calendar.startOfDay(for: requestedBounds.start)
        let end = calendar.startOfDay(for: requestedBounds.end)
        let values = days.filter { $0.start >= start && $0.start <= end }
        guard let first = values.first, let last = values.last else { return self }
        let knownDayCount = values.filter { $0.state != .unknown }.count
        let availability: UsageActivityAvailability
        if knownDayCount == values.count {
            availability = .complete
        } else if knownDayCount > 0 {
            availability = .partial
        } else {
            availability = .unavailable
        }
        return UsageActivityDataset(
            bounds: UsageDateBounds(start: first.start, end: last.start),
            days: values,
            availability: availability,
            unavailableReason: unavailableReason
        )
    }

    func suffixDays(_ count: Int, calendar: Calendar = .current) -> UsageActivityDataset {
        guard let first = days.suffix(count).first else { return self }
        return clipped(to: UsageDateBounds(start: first.start, end: bounds.end), calendar: calendar)
    }

    func calendarWeeks(_ count: Int, calendar: Calendar = .current) -> UsageActivityDataset {
        guard count > 0, let reference = days.last?.start else { return self }
        let referenceDay = calendar.startOfDay(for: reference)
        let weekdayIndex = (calendar.component(.weekday, from: referenceDay) + 5) % 7
        guard let currentWeekStart = calendar.date(byAdding: .day, value: -weekdayIndex, to: referenceDay),
              let firstWeekStart = calendar.date(byAdding: .weekOfYear, value: -(count - 1), to: currentWeekStart) else {
            return self
        }
        return clipped(to: UsageDateBounds(start: firstWeekStart, end: referenceDay), calendar: calendar)
    }
}

enum UsageActivitySeries {
    static func dataset(
        points: [UsageTrendPoint],
        bounds: UsageDateBounds,
        knownBounds: [UsageDateBounds],
        unavailableReason: UsageActivityUnavailableReason? = nil,
        calendar: Calendar = .current
    ) -> UsageActivityDataset {
        let pointsByDay = Dictionary(grouping: points) { point in
            calendar.startOfDay(for: Date(timeIntervalSince1970: TimeInterval(point.bucketStartMs) / 1_000))
        }
        var days: [UsageActivityDay] = []
        var cursor = calendar.startOfDay(for: bounds.start)
        let end = calendar.startOfDay(for: bounds.end)

        while cursor <= end, days.count < 367 {
            let matches = pointsByDay[cursor] ?? []
            let requests = matches.reduce(0) { $0 + $1.requests }
            let failures = matches.reduce(0) { $0 + $1.failures }
            let tokens = matches.reduce(0) { $0 + $1.tokens }
            let isKnown = knownBounds.contains { range in
                cursor >= calendar.startOfDay(for: range.start) && cursor <= calendar.startOfDay(for: range.end)
            }
            let state: UsageActivityDayState
            if !matches.isEmpty && (requests > 0 || failures > 0 || tokens > 0) {
                state = .observed
            } else if isKnown {
                state = .knownZero
            } else {
                state = .unknown
            }
            days.append(UsageActivityDay(
                start: cursor,
                requests: requests,
                failures: failures,
                tokens: tokens,
                state: state
            ))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        let knownDayCount = days.filter { $0.state != .unknown }.count
        let availability: UsageActivityAvailability
        if knownDayCount == days.count {
            availability = .complete
        } else if knownDayCount > 0 {
            availability = .partial
        } else {
            availability = .unavailable
        }
        return UsageActivityDataset(
            bounds: bounds,
            days: days,
            availability: availability,
            unavailableReason: unavailableReason
        )
    }

    static func unavailable(
        bounds: UsageDateBounds,
        reason: UsageActivityUnavailableReason,
        calendar: Calendar = .current
    ) -> UsageActivityDataset {
        dataset(points: [], bounds: bounds, knownBounds: [], unavailableReason: reason, calendar: calendar)
    }

    static func aggregateSources(
        _ datasets: [UsageActivityDataset],
        expectedSourceCount: Int,
        calendar: Calendar = .current
    ) -> UsageActivityDataset {
        guard let first = datasets.first else {
            let fallback = UsageDateBounds(start: Date(), end: Date())
            return unavailable(bounds: fallback, reason: .requestFailed, calendar: calendar)
        }
        let bounds = first.bounds
        let dayCount = first.days.count
        var days: [UsageActivityDay] = []

        for index in 0..<dayCount {
            let sourceDays = datasets.compactMap { $0.days.indices.contains(index) ? $0.days[index] : nil }
            let covered = sourceDays.filter { $0.state == .observed || $0.state == .knownZero }
            let hasMissingSource = datasets.count < expectedSourceCount || sourceDays.count < expectedSourceCount
            let hasIncompleteSource = sourceDays.contains { $0.state == .partial || $0.state == .unknown }
            let requests = covered.reduce(0) { $0 + $1.requests }
            let failures = covered.reduce(0) { $0 + $1.failures }
            let tokens = covered.reduce(0) { $0 + $1.tokens }
            let state: UsageActivityDayState
            if covered.isEmpty {
                state = .unknown
            } else if hasMissingSource || hasIncompleteSource || covered.count < expectedSourceCount {
                state = .partial
            } else if requests > 0 || failures > 0 || tokens > 0 {
                state = .observed
            } else {
                state = .knownZero
            }
            days.append(UsageActivityDay(start: first.days[index].start, requests: requests, failures: failures, tokens: tokens, state: state))
        }

        let complete = days.allSatisfy { $0.state == .observed || $0.state == .knownZero }
        let anyKnown = days.contains { $0.state != .unknown }
        return UsageActivityDataset(
            bounds: bounds,
            days: days,
            availability: complete ? .complete : (anyKnown ? .partial : .unavailable),
            unavailableReason: anyKnown ? nil : datasets.compactMap(\.unavailableReason).first
        )
    }

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

    static func intensity(value: Int, distribution: [Int]) -> Int {
        intensity(value: value, sortedDistribution: sortedDistribution(distribution))
    }

    /// Positive values in ascending order, reusable across every cell of one heatmap pass.
    static func sortedDistribution(_ distribution: [Int]) -> [Int] {
        distribution.filter { $0 > 0 }.sorted()
    }

    static func intensity(value: Int, sortedDistribution values: [Int]) -> Int {
        guard value > 0, !values.isEmpty else { return 0 }
        let rank = values.partitioningIndex { $0 > value }
        return min(4, max(1, Int(ceil(Double(rank) / Double(values.count) * 4))))
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

private extension Array where Element == Int {
    func partitioningIndex(where belongsInSecondPartition: (Int) -> Bool) -> Int {
        var lower = startIndex
        var upper = endIndex
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if belongsInSecondPartition(self[middle]) {
                upper = middle
            } else {
                lower = middle + 1
            }
        }
        return lower
    }
}
