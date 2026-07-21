import AppKit

final class ActivityMenuCardView: RoundedPanelView {
    private let periods = UsageActivityPeriod.allCases
    private let granularities = UsageActivityGranularity.allCases
    private let selectedLabel = menuLabel("--", size: 9, weight: .bold, color: RelayTheme.muted)
    private let onPeriodSelected: (UsageActivityPeriod) -> Void
    private let onGranularitySelected: (UsageActivityGranularity) -> Void

    init(
        points: [UsageTrendPoint],
        period: UsageActivityPeriod,
        bounds: UsageDateBounds,
        granularity: UsageActivityGranularity,
        texts: TextBundle,
        onPeriodSelected: @escaping (UsageActivityPeriod) -> Void,
        onGranularitySelected: @escaping (UsageActivityGranularity) -> Void
    ) {
        self.onPeriodSelected = onPeriodSelected
        self.onGranularitySelected = onGranularitySelected
        super.init(accentColor: RelayTheme.line, fillAlpha: 0.94)
        build(points: points, period: period, bounds: bounds, granularity: granularity, texts: texts)
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func build(
        points: [UsageTrendPoint],
        period: UsageActivityPeriod,
        bounds: UsageDateBounds,
        granularity: UsageActivityGranularity,
        texts: TextBundle
    ) {
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 356).isActive = true

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 7
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 9),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -9)
        ])

        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 8
        header.addArrangedSubview(menuIconTitle(texts.activity, accent: RelayTheme.up, icon: .tokens))
        header.addArrangedSubview(NSView())
        header.addArrangedSubview(periodPopup(selected: period, texts: texts))
        stack.addArrangedSubview(header)

        stack.addArrangedSubview(granularityTabs(selected: granularity, texts: texts))

        let buckets = UsageActivitySeries.aggregate(points, granularity: granularity)
        let heatmap = ActivityHeatmapView(buckets: buckets, bounds: bounds, granularity: granularity) { [weak self] bucket in
            self?.selectedLabel.stringValue = self?.summary(bucket, texts: texts) ?? "--"
        }
        heatmap.translatesAutoresizingMaskIntoConstraints = false
        heatmap.widthAnchor.constraint(equalToConstant: 332).isActive = true
        heatmap.heightAnchor.constraint(equalToConstant: 82).isActive = true
        stack.addArrangedSubview(heatmap)

        let footer = NSStackView()
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.spacing = 6
        footer.addArrangedSubview(legend(texts: texts))
        footer.addArrangedSubview(NSView())
        selectedLabel.alignment = .right
        selectedLabel.lineBreakMode = .byTruncatingMiddle
        selectedLabel.stringValue = summary(buckets.last, texts: texts)
        footer.addArrangedSubview(selectedLabel)
        stack.addArrangedSubview(footer)
    }

    private func periodPopup(selected: UsageActivityPeriod, texts: TextBundle) -> NSPopUpButton {
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.addItems(withTitles: periods.map(texts.activityPeriodLabel))
        popup.selectItem(at: periods.firstIndex(of: selected) ?? 0)
        popup.target = self
        popup.action = #selector(periodChanged(_:))
        popup.font = RelayTheme.font(size: 10, weight: .bold)
        popup.contentTintColor = RelayTheme.text
        popup.bezelStyle = .regularSquare
        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.widthAnchor.constraint(equalToConstant: 126).isActive = true
        popup.heightAnchor.constraint(equalToConstant: 26).isActive = true
        return popup
    }

    private func granularityTabs(selected: UsageActivityGranularity, texts: TextBundle) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fillEqually
        row.spacing = 0
        row.translatesAutoresizingMaskIntoConstraints = false
        row.widthAnchor.constraint(equalToConstant: 332).isActive = true
        row.heightAnchor.constraint(equalToConstant: 28).isActive = true

        for (index, granularity) in granularities.enumerated() {
            let button = NSButton(title: texts.activityGranularityLabel(granularity), target: self, action: #selector(granularityChanged(_:)))
            button.tag = index
            button.setButtonType(.momentaryPushIn)
            RelayTheme.styleButton(
                button,
                tint: granularity == selected ? RelayTheme.up : RelayTheme.line,
                isSelected: granularity == selected,
                fontSize: 9
            )
            row.addArrangedSubview(button)
        }
        return row
    }

    private func legend(texts: TextBundle) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 3
        row.addArrangedSubview(menuLabel(texts.activityLess.uppercased(), size: 8, weight: .bold, color: RelayTheme.muted))
        for color in RelayTheme.activityLevels {
            let swatch = NSView()
            swatch.wantsLayer = true
            swatch.layer?.backgroundColor = color.cgColor
            swatch.translatesAutoresizingMaskIntoConstraints = false
            swatch.widthAnchor.constraint(equalToConstant: 8).isActive = true
            swatch.heightAnchor.constraint(equalToConstant: 8).isActive = true
            row.addArrangedSubview(swatch)
        }
        row.addArrangedSubview(menuLabel(texts.activityMore.uppercased(), size: 8, weight: .bold, color: RelayTheme.muted))
        return row
    }

    private func summary(_ bucket: UsageActivityBucket?, texts: TextBundle) -> String {
        guard let bucket else { return "--" }
        let date = DateFormatter.localizedString(from: bucket.start, dateStyle: .short, timeStyle: .none)
        return "\(date)  \(MenuValueFormatter.compact(bucket.tokens)) \(texts.tokenUnit.uppercased())"
    }

    @objc private func periodChanged(_ sender: NSPopUpButton) {
        guard periods.indices.contains(sender.indexOfSelectedItem) else { return }
        onPeriodSelected(periods[sender.indexOfSelectedItem])
    }

    @objc private func granularityChanged(_ sender: NSButton) {
        guard granularities.indices.contains(sender.tag) else { return }
        onGranularitySelected(granularities[sender.tag])
    }
}

private final class ActivityHeatmapView: NSView {
    private struct Cell {
        let rect: NSRect
        let bucket: UsageActivityBucket
    }

    private let buckets: [UsageActivityBucket]
    private let dateBounds: UsageDateBounds
    private let granularity: UsageActivityGranularity
    private let onSelect: (UsageActivityBucket?) -> Void
    private var cells: [Cell] = []
    private var selectedIndex: Int?
    private var trackingArea: NSTrackingArea?

    init(
        buckets: [UsageActivityBucket],
        bounds: UsageDateBounds,
        granularity: UsageActivityGranularity,
        onSelect: @escaping (UsageActivityBucket?) -> Void
    ) {
        self.buckets = buckets
        self.dateBounds = bounds
        self.granularity = granularity
        self.onSelect = onSelect
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        cells = makeCells()
        let maximum = cells.map(\.bucket.tokens).max() ?? 0
        for (index, cell) in cells.enumerated() {
            let level = UsageActivitySeries.intensity(value: cell.bucket.tokens, maximum: maximum)
            RelayTheme.activityLevels[level].setFill()
            NSBezierPath(rect: cell.rect).fill()
            if index == selectedIndex {
                RelayTheme.text.setStroke()
                let outline = NSBezierPath(rect: cell.rect.insetBy(dx: -1, dy: -1))
                outline.lineWidth = 1
                outline.stroke()
            }
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        selectedIndex = cells.firstIndex { $0.rect.insetBy(dx: -1, dy: -1).contains(point) }
        onSelect(selectedIndex.map { cells[$0].bucket })
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        selectedIndex = nil
        onSelect(buckets.last)
        needsDisplay = true
    }

    private func makeCells() -> [Cell] {
        let calendar = Calendar.current
        let timeline = completeTimeline(calendar: calendar)
        guard !timeline.isEmpty else { return [] }
        let gap: CGFloat = granularity == .monthly ? 4 : 2
        let layout = gridLayout(count: timeline.count, calendar: calendar)
        let cellSize = min(layout.maximumCellSize, floor((bounds.width - CGFloat(layout.columns - 1) * gap) / CGFloat(layout.columns)))
        let totalWidth = CGFloat(layout.columns) * cellSize + CGFloat(layout.columns - 1) * gap
        let totalHeight = CGFloat(layout.rows) * cellSize + CGFloat(layout.rows - 1) * gap
        let originX = floor((bounds.width - totalWidth) / 2)
        let originY = floor((bounds.height - totalHeight) / 2)

        return timeline.enumerated().map { index, bucket in
            let position = layout.position(index)
            let x = originX + CGFloat(position.column) * (cellSize + gap)
            let y = bounds.height - originY - CGFloat(position.row + 1) * cellSize - CGFloat(position.row) * gap
            return Cell(rect: NSRect(x: x, y: y, width: cellSize, height: cellSize), bucket: bucket)
        }
    }

    private func completeTimeline(calendar: Calendar) -> [UsageActivityBucket] {
        let values = Dictionary(uniqueKeysWithValues: buckets.map { ($0.start, $0) })
        var result: [UsageActivityBucket] = []
        var cursor = bucketStart(for: dateBounds.start, calendar: calendar)
        let end = bucketStart(for: dateBounds.end, calendar: calendar)
        let component: Calendar.Component = granularity == .monthly ? .month : .day
        let step = granularity == .weekly ? 7 : 1

        while cursor <= end, result.count < 400 {
            result.append(values[cursor] ?? UsageActivityBucket(start: cursor, requests: 0, failures: 0, tokens: 0))
            guard let next = calendar.date(byAdding: component, value: step, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    private func bucketStart(for date: Date, calendar: Calendar) -> Date {
        switch granularity {
        case .daily, .cumulative:
            return calendar.startOfDay(for: date)
        case .weekly:
            let day = calendar.startOfDay(for: date)
            let weekday = calendar.component(.weekday, from: day)
            return calendar.date(byAdding: .day, value: -((weekday + 5) % 7), to: day) ?? day
        case .monthly:
            return calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
        }
    }

    private func gridLayout(count: Int, calendar: Calendar) -> GridLayout {
        if granularity == .daily || granularity == .cumulative {
            let weekdayOffset = (calendar.component(.weekday, from: calendar.startOfDay(for: dateBounds.start)) + 5) % 7
            let columns = max(1, Int(ceil(Double(weekdayOffset + count) / 7)))
            return GridLayout(columns: columns, rows: 7, maximumCellSize: 11) { index in
                let value = weekdayOffset + index
                return (value / 7, value % 7)
            }
        }
        if granularity == .weekly {
            let rows = min(4, max(1, count))
            let columns = max(1, Int(ceil(Double(count) / Double(rows))))
            return GridLayout(columns: columns, rows: rows, maximumCellSize: 12) { index in
                (index / rows, index % rows)
            }
        }
        return GridLayout(columns: max(1, count), rows: 1, maximumCellSize: 18) { index in (index, 0) }
    }
}

private struct GridLayout {
    let columns: Int
    let rows: Int
    let maximumCellSize: CGFloat
    let position: (Int) -> (column: Int, row: Int)
}
