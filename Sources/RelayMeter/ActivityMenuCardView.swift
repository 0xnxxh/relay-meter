import AppKit

enum UsageActivityMetric: String, CaseIterable {
    case requests
    case tokens
}

final class ActivityMenuCardView: RoundedPanelView {
    private let selectedLabel = menuLabel("--", size: 9, weight: .bold, color: RelayTheme.muted)
    private let onOpenDetails: () -> Void

    init(
        dataset: UsageActivityDataset,
        texts: TextBundle,
        onOpenDetails: @escaping () -> Void
    ) {
        self.onOpenDetails = onOpenDetails
        super.init(accentColor: RelayTheme.line, fillAlpha: 0.94)
        build(dataset: dataset, texts: texts)
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func build(dataset: UsageActivityDataset, texts: TextBundle) {
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
        let details = NSButton(title: texts.activityViewDetails, target: self, action: #selector(openDetails))
        details.translatesAutoresizingMaskIntoConstraints = false
        details.heightAnchor.constraint(equalToConstant: 26).isActive = true
        details.widthAnchor.constraint(equalToConstant: 94).isActive = true
        details.setAccessibilityLabel(texts.activityViewDetails)
        RelayTheme.styleButton(details, tint: RelayTheme.up, fontSize: 9)
        header.addArrangedSubview(details)
        stack.addArrangedSubview(header)

        let recent = dataset.calendarWeeks(13)
        let heatmap = ActivityHeatmapView(dataset: recent, metric: .requests, layout: .compact) { [weak self] day in
            self?.selectedLabel.stringValue = self?.summary(day, texts: texts) ?? "--"
        }
        heatmap.translatesAutoresizingMaskIntoConstraints = false
        heatmap.widthAnchor.constraint(equalToConstant: 332).isActive = true
        heatmap.heightAnchor.constraint(equalToConstant: 112).isActive = true
        stack.addArrangedSubview(heatmap)

        let footer = NSStackView()
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.spacing = 6
        footer.addArrangedSubview(ActivityLegendView(texts: texts))
        footer.addArrangedSubview(NSView())
        selectedLabel.alignment = .right
        selectedLabel.lineBreakMode = .byTruncatingMiddle
        selectedLabel.stringValue = availabilitySummary(dataset, texts: texts)
        footer.addArrangedSubview(selectedLabel)
        stack.addArrangedSubview(footer)
    }

    private func availabilitySummary(_ dataset: UsageActivityDataset, texts: TextBundle) -> String {
        switch dataset.availability {
        case .complete:
            return summary(dataset.days.last, texts: texts)
        case .partial:
            return texts.activityPartial
        case .unavailable:
            return dataset.unavailableReason == .dataExportDisabled
                ? texts.activityDataExportDisabled
                : texts.activityUnavailable
        }
    }

    private func summary(_ day: UsageActivityDay?, texts: TextBundle) -> String {
        guard let day else { return "--" }
        let date = DateFormatter.localizedString(from: day.start, dateStyle: .short, timeStyle: .none)
        switch day.state {
        case .unknown:
            return "\(date)  \(texts.activityUnknown)"
        case .partial:
            return "\(date)  \(MenuValueFormatter.compact(day.requests)) · \(texts.activityPartial)"
        case .observed, .knownZero:
            return "\(date)  \(MenuValueFormatter.compact(day.requests)) \(texts.requests.uppercased())"
        }
    }

    @objc private func openDetails() {
        onOpenDetails()
    }

}

final class ActivityLegendView: NSView {
    init(texts: TextBundle, includeUnknown: Bool = false) {
        super.init(frame: .zero)
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 3
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
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
        if includeUnknown {
            row.addArrangedSubview(menuLabel("□ \(texts.activityUnknown.uppercased())", size: 8, weight: .bold, color: RelayTheme.muted))
        }
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }
}

final class ActivityHeatmapView: NSView {
    static let compactColumnCount = 13
    static let compactRowCount = 7
    static let compactGap: CGFloat = 4

    static func compactGridPosition(
        for date: Date,
        reference: Date,
        calendar: Calendar = .current
    ) -> (column: Int, row: Int)? {
        let referenceDay = calendar.startOfDay(for: reference)
        let referenceRow = (calendar.component(.weekday, from: referenceDay) + 5) % 7
        guard let currentWeekStart = calendar.date(byAdding: .day, value: -referenceRow, to: referenceDay),
              let firstWeekStart = calendar.date(byAdding: .weekOfYear, value: -(compactColumnCount - 1), to: currentWeekStart) else {
            return nil
        }
        let day = calendar.startOfDay(for: date)
        guard day >= firstWeekStart, day <= referenceDay else { return nil }
        let column = calendar.dateComponents([.day], from: firstWeekStart, to: day).day.map { $0 / 7 } ?? -1
        let row = (calendar.component(.weekday, from: day) + 5) % 7
        guard (0..<compactColumnCount).contains(column), (0..<compactRowCount).contains(row) else { return nil }
        return (column, row)
    }

    enum Layout {
        case compact
        case calendar
    }

    private struct Cell {
        let rect: NSRect
        let day: UsageActivityDay
    }

    private let dataset: UsageActivityDataset
    private let metric: UsageActivityMetric
    private let heatmapLayout: Layout
    private let onSelect: (UsageActivityDay?) -> Void
    private var cells: [Cell] = []
    private var selectedIndex: Int?
    private var trackingArea: NSTrackingArea?

    init(
        dataset: UsageActivityDataset,
        metric: UsageActivityMetric,
        layout: Layout,
        onSelect: @escaping (UsageActivityDay?) -> Void
    ) {
        self.dataset = dataset
        self.metric = metric
        self.heatmapLayout = layout
        self.onSelect = onSelect
        super.init(frame: .zero)
        wantsLayer = true
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        cells = makeCells()
        let distribution = cells.compactMap { cell -> Int? in
            guard cell.day.state == .observed || cell.day.state == .partial else { return nil }
            return value(for: cell.day)
        }
        for (index, cell) in cells.enumerated() {
            draw(cell: cell, distribution: distribution, selected: index == selectedIndex)
        }
        drawAxes()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        select(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        select(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseExited(with event: NSEvent) {
        selectedIndex = nil
        onSelect(dataset.days.last)
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        let delta: Int
        switch (heatmapLayout, event.keyCode) {
        case (.compact, 123): delta = -7
        case (.compact, 124): delta = 7
        case (.compact, 125): delta = 1
        case (.compact, 126): delta = -1
        case (.calendar, 123): delta = -7
        case (.calendar, 124): delta = 7
        case (.calendar, 125): delta = 1
        case (.calendar, 126): delta = -1
        default:
            super.keyDown(with: event)
            return
        }
        let current = selectedIndex ?? max(0, cells.count - 1)
        selectedIndex = min(max(0, current + delta), max(0, cells.count - 1))
        onSelect(cells.indices.contains(selectedIndex ?? -1) ? cells[selectedIndex!].day : nil)
        needsDisplay = true
    }

    private func select(at point: NSPoint) {
        selectedIndex = cells.firstIndex { $0.rect.insetBy(dx: -1, dy: -1).contains(point) }
        onSelect(selectedIndex.map { cells[$0].day })
        needsDisplay = true
    }

    private func draw(cell: Cell, distribution: [Int], selected: Bool) {
        let path = NSBezierPath(rect: cell.rect)
        switch cell.day.state {
        case .unknown:
            RelayTheme.activityUnknown.setFill()
            path.fill()
            drawHatch(in: cell.rect)
        case .knownZero:
            RelayTheme.activityLevels[0].setFill()
            path.fill()
        case .observed, .partial:
            let level = UsageActivitySeries.intensity(value: value(for: cell.day), distribution: distribution)
            RelayTheme.activityLevels[level].setFill()
            path.fill()
            if cell.day.state == .partial {
                RelayTheme.warn.setStroke()
                path.lineWidth = 1
                path.stroke()
            }
        }
        if selected {
            RelayTheme.text.setStroke()
            let outline = NSBezierPath(rect: cell.rect.insetBy(dx: -2, dy: -2))
            outline.lineWidth = 1
            outline.stroke()
        }
    }

    private func drawHatch(in rect: NSRect) {
        RelayTheme.line.setStroke()
        let hatch = NSBezierPath()
        hatch.move(to: NSPoint(x: rect.minX, y: rect.minY))
        hatch.line(to: NSPoint(x: rect.maxX, y: rect.maxY))
        hatch.move(to: NSPoint(x: rect.midX, y: rect.minY))
        hatch.line(to: NSPoint(x: rect.maxX, y: rect.midY))
        hatch.lineWidth = 0.7
        hatch.stroke()
    }

    private func value(for day: UsageActivityDay) -> Int {
        metric == .requests ? day.requests : day.tokens
    }

    private func makeCells() -> [Cell] {
        guard !dataset.days.isEmpty else { return [] }
        switch heatmapLayout {
        case .compact:
            let calendar = Calendar.current
            let leftInset: CGFloat = 23
            let topInset: CGFloat = 18
            let horizontalGap = Self.compactGap
            let verticalGap: CGFloat = 3
            let cellWidth = floor(
                (bounds.width - leftInset - CGFloat(Self.compactColumnCount - 1) * horizontalGap)
                    / CGFloat(Self.compactColumnCount)
            )
            let cellHeight: CGFloat = 11
            guard let reference = dataset.days.last?.start else { return [] }
            return dataset.days.compactMap { day in
                guard let position = Self.compactGridPosition(
                    for: day.start,
                    reference: reference,
                    calendar: calendar
                ) else { return nil }
                return Cell(rect: NSRect(
                    x: leftInset + CGFloat(position.column) * (cellWidth + horizontalGap),
                    y: bounds.height - topInset - CGFloat(position.row + 1) * cellHeight - CGFloat(position.row) * verticalGap,
                    width: cellWidth,
                    height: cellHeight
                ), day: day)
            }
        case .calendar:
            let calendar = Calendar.current
            let leftInset: CGFloat = 38
            let topInset: CGFloat = 24
            let gap: CGFloat = 3
            let weekdayOffset = (calendar.component(.weekday, from: dataset.days[0].start) + 5) % 7
            let columns = max(1, Int(ceil(Double(weekdayOffset + dataset.days.count) / 7)))
            let availableWidth = bounds.width - leftInset
            let cellSize = min(12, floor((availableWidth - CGFloat(columns - 1) * gap) / CGFloat(columns)))
            return dataset.days.enumerated().map { index, day in
                let value = weekdayOffset + index
                let column = value / 7
                let row = value % 7
                return Cell(rect: NSRect(
                    x: leftInset + CGFloat(column) * (cellSize + gap),
                    y: bounds.height - topInset - CGFloat(row + 1) * cellSize - CGFloat(row) * gap,
                    width: cellSize,
                    height: cellSize
                ), day: day)
            }
        }
    }

    private func drawAxes() {
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: RelayTheme.font(size: 9, weight: .bold),
            .foregroundColor: RelayTheme.muted
        ]
        let weekdayLabels = Calendar.current.shortWeekdaySymbols
        let rowStep: CGFloat = heatmapLayout == .compact ? 14 : 15
        let firstRowY: CGFloat = heatmapLayout == .compact ? bounds.height - 28 : bounds.height - 26
        for row in [0, 2, 4] {
            let symbolIndex = (row + 1) % 7
            let label = weekdayLabels[symbolIndex]
            label.draw(at: NSPoint(x: 2, y: firstRowY - CGFloat(row) * rowStep), withAttributes: labelAttributes)
        }
        var monthLabels: [(text: String, point: NSPoint, width: CGFloat)] = []
        var lastMonth = DateComponents()
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        for cell in cells {
            let month = Calendar.current.dateComponents([.year, .month], from: cell.day.start)
            if month != lastMonth {
                let text = formatter.string(from: cell.day.start)
                monthLabels.append((
                    text: text,
                    point: NSPoint(x: cell.rect.minX, y: bounds.height - 15),
                    width: text.size(withAttributes: labelAttributes).width
                ))
                lastMonth = month
            }
        }
        var lastLabelMaxX = -CGFloat.greatestFiniteMagnitude
        for (index, label) in monthLabels.enumerated() {
            if index == 0,
               monthLabels.indices.contains(1),
               label.point.x + label.width + 6 > monthLabels[1].point.x {
                continue
            }
            guard label.point.x >= lastLabelMaxX + 6 else { continue }
            label.text.draw(at: label.point, withAttributes: labelAttributes)
            lastLabelMaxX = label.point.x + label.width
        }
    }
}
