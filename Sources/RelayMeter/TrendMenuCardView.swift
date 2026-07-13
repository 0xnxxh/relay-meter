import AppKit

final class TrendMenuCardView: RoundedPanelView {
    private let points: [UsageTrendPoint]
    private let texts: TextBundle
    private let selectedLabel: NSTextField

    init(points: [UsageTrendPoint], texts: TextBundle) {
        self.points = points
        self.texts = texts
        self.selectedLabel = menuLabel("", size: 10, weight: .bold, color: RelayTheme.muted)
        super.init(accentColor: RelayTheme.line, fillAlpha: 0.92)
        selectedLabel.stringValue = valueText(points.last)
        build()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func build() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])

        stack.addArrangedSubview(menuIconTitle(texts.trend, accent: RelayTheme.accent, icon: .trend))
        let chart = TrendChartView(points: points) { [weak self] point in
            self?.selectedLabel.stringValue = self?.valueText(point) ?? "--"
        }
        chart.translatesAutoresizingMaskIntoConstraints = false
        chart.heightAnchor.constraint(equalToConstant: 64).isActive = true
        chart.widthAnchor.constraint(equalToConstant: 332).isActive = true
        stack.addArrangedSubview(chart)

        let summaryRow = NSStackView()
        summaryRow.orientation = .horizontal
        summaryRow.alignment = .firstBaseline
        summaryRow.spacing = 8
        summaryRow.addArrangedSubview(legend())
        summaryRow.addArrangedSubview(NSView())
        selectedLabel.alignment = .right
        selectedLabel.lineBreakMode = .byTruncatingMiddle
        summaryRow.addArrangedSubview(selectedLabel)
        stack.addArrangedSubview(summaryRow)
    }

    private func legend() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.addArrangedSubview(legendItem(texts.requests, color: RelayTheme.cyan))
        row.addArrangedSubview(legendItem(texts.tokens, color: RelayTheme.accent))
        return row
    }

    private func valueText(_ point: UsageTrendPoint?) -> String {
        guard let point else { return "--" }
        return "\(point.label)  \(MenuValueFormatter.number(point.requests)) REQ  \(MenuValueFormatter.compact(point.tokens)) TOKEN  \(MenuValueFormatter.number(point.failures)) ERR"
    }

    private func legendItem(_ title: String, color: NSColor) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 4
        let dot = StatusDotView(color: color)
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.widthAnchor.constraint(equalToConstant: 11).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 11).isActive = true
        row.addArrangedSubview(dot)
        row.addArrangedSubview(menuLabel(title.uppercased(), size: 10, weight: .bold, color: RelayTheme.muted))
        return row
    }
}

final class TrendChartView: NSView {
    private let points: [UsageTrendPoint]
    private let onSelect: (UsageTrendPoint?) -> Void
    private var selectedIndex: Int?
    private var trackingArea: NSTrackingArea?

    init(points: [UsageTrendPoint], onSelect: @escaping (UsageTrendPoint?) -> Void) {
        self.points = points
        self.onSelect = onSelect
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        RelayTheme.raised.setFill()
        bounds.fill()
        drawGrid()
        guard points.count >= 2 else {
            drawEmpty()
            return
        }
        drawSeries(values: points.map(\.tokens), color: RelayTheme.accent)
        drawSeries(values: points.map(\.requests), color: RelayTheme.cyan)
        drawSelection()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let options: NSTrackingArea.Options = [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        let nextArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(nextArea)
        trackingArea = nextArea
    }

    override func mouseMoved(with event: NSEvent) {
        guard points.count >= 2 else { return }
        let location = convert(event.locationInWindow, from: nil)
        let clampedX = min(max(location.x, bounds.minX), bounds.maxX)
        let ratio = bounds.width > 0 ? (clampedX - bounds.minX) / bounds.width : 0
        selectedIndex = min(max(Int(round(ratio * CGFloat(points.count - 1))), 0), points.count - 1)
        onSelect(selectedIndex.map { points[$0] })
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        selectedIndex = nil
        onSelect(points.last)
        needsDisplay = true
    }

    private func drawGrid() {
        RelayTheme.line.withAlphaComponent(0.35).setStroke()
        for index in 0..<4 {
            let y = bounds.minY + CGFloat(index) * bounds.height / 3
            let path = NSBezierPath()
            path.move(to: NSPoint(x: bounds.minX, y: y))
            path.line(to: NSPoint(x: bounds.maxX, y: y))
            path.lineWidth = 1
            path.stroke()
        }
    }

    private func drawSeries(values: [Int], color: NSColor) {
        let maxValue = max(values.max() ?? 0, 1)
        let seriesPoints = values.enumerated().map { index, value in
            chartPoint(index: index, value: value, maxValue: maxValue)
        }
        let path = smoothPath(points: seriesPoints)
        color.withAlphaComponent(0.95).setStroke()
        path.lineWidth = 1.5
        path.lineJoinStyle = .miter
        path.lineCapStyle = .butt
        path.stroke()
    }

    private func smoothPath(points: [NSPoint]) -> NSBezierPath {
        let path = NSBezierPath()
        guard let first = points.first else { return path }
        path.move(to: first)
        guard points.count > 2 else {
            for point in points.dropFirst() {
                path.line(to: point)
            }
            return path
        }

        for index in 0..<(points.count - 1) {
            let previous = index == 0 ? points[index] : points[index - 1]
            let current = points[index]
            let next = points[index + 1]
            let following = index + 2 < points.count ? points[index + 2] : next
            let firstControl = NSPoint(
                x: current.x + (next.x - previous.x) / 6,
                y: current.y + (next.y - previous.y) / 6
            )
            let secondControl = NSPoint(
                x: next.x - (following.x - current.x) / 6,
                y: next.y - (following.y - current.y) / 6
            )
            path.curve(to: next, controlPoint1: firstControl, controlPoint2: secondControl)
        }
        return path
    }

    private func drawSelection() {
        guard let selectedIndex, selectedIndex < points.count else { return }
        let maxTokens = max(points.map(\.tokens).max() ?? 0, 1)
        let maxRequests = max(points.map(\.requests).max() ?? 0, 1)
        let tokenPoint = chartPoint(index: selectedIndex, value: points[selectedIndex].tokens, maxValue: maxTokens)
        let requestPoint = chartPoint(index: selectedIndex, value: points[selectedIndex].requests, maxValue: maxRequests)
        RelayTheme.text.withAlphaComponent(0.35).setStroke()
        let guide = NSBezierPath()
        guide.move(to: NSPoint(x: tokenPoint.x, y: bounds.minY))
        guide.line(to: NSPoint(x: tokenPoint.x, y: bounds.maxY))
        guide.lineWidth = 1
        guide.stroke()
        drawPoint(tokenPoint, color: RelayTheme.accent)
        drawPoint(requestPoint, color: RelayTheme.cyan)
    }

    private func chartPoint(index: Int, value: Int, maxValue: Int) -> NSPoint {
        let x = bounds.minX + CGFloat(index) / CGFloat(points.count - 1) * bounds.width
        let y = bounds.minY + CGFloat(value) / CGFloat(maxValue) * bounds.height
        return NSPoint(x: x, y: y)
    }

    private func drawPoint(_ point: NSPoint, color: NSColor) {
        color.setFill()
        NSBezierPath(rect: NSRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)).fill()
    }

    private func drawEmpty() {
        let text = "--" as NSString
        text.draw(
            at: NSPoint(x: bounds.midX - 8, y: bounds.midY - 7),
            withAttributes: [
                .font: RelayTheme.font(size: 12, weight: .bold),
                .foregroundColor: RelayTheme.muted
            ]
        )
    }
}
