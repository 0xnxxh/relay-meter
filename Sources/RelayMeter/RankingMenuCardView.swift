// Hallmark · interactive ranking card · RelayTheme pixel UI · pre-emit: P5 H5 E5 S5 R5 V4 · default/hover/keyboard render pass · contrast pass
import AppKit

final class RankingMenuCardView: RoundedPanelView {
    private static let rankColors = [RelayTheme.accent, RelayTheme.cyan, RelayTheme.up]
    private let chartDetail = menuLabel("", size: 9, weight: .bold, color: RelayTheme.muted)

    init(snapshot: UsageSnapshot, texts: TextBundle) {
        super.init(accentColor: RelayTheme.line, fillAlpha: 0.92)
        build(rows: Array(snapshot.topModels.prefix(3)), texts: texts)
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func build(rows: [UsageRankingRow], texts: TextBundle) {
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

        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 8
        header.translatesAutoresizingMaskIntoConstraints = false
        header.widthAnchor.constraint(equalToConstant: 332).isActive = true
        header.addArrangedSubview(menuIconTitle(texts.topModel, accent: RelayTheme.cyan, icon: .ranking))
        header.addArrangedSubview(NSView())
        chartDetail.identifier = NSUserInterfaceItemIdentifier("top-model-token-share-detail")
        chartDetail.stringValue = "\(texts.tokens.uppercased()) %"
        chartDetail.alignment = .right
        chartDetail.lineBreakMode = .byTruncatingMiddle
        header.addArrangedSubview(chartDetail)
        stack.addArrangedSubview(header)

        let content = NSStackView()
        content.orientation = .horizontal
        content.alignment = .top
        content.spacing = 12
        content.translatesAutoresizingMaskIntoConstraints = false
        content.widthAnchor.constraint(equalToConstant: 332).isActive = true

        let ranking = rankingColumn(title: texts.topModel, rows: rows)
        ranking.translatesAutoresizingMaskIntoConstraints = false
        ranking.widthAnchor.constraint(equalToConstant: 232).isActive = true
        content.addArrangedSubview(ranking)
        content.addArrangedSubview(chartColumn(rows: rows, texts: texts))
        stack.addArrangedSubview(content)
    }

    private func rankingColumn(title: String, rows: [UsageRankingRow]) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 3
        stack.addArrangedSubview(menuLabel(title.uppercased(), size: 10, weight: .bold, color: RelayTheme.muted))

        guard !rows.isEmpty else {
            stack.addArrangedSubview(menuLabel("--", size: 11, weight: .bold, color: RelayTheme.muted))
            return stack
        }

        for (index, row) in rows.enumerated() {
            let item = NSStackView()
            item.orientation = .vertical
            item.alignment = .leading
            item.spacing = 1

            let nameRow = NSStackView()
            nameRow.orientation = .horizontal
            nameRow.alignment = .firstBaseline
            nameRow.spacing = 5
            let rankColor = Self.rankColors[index]
            nameRow.addArrangedSubview(menuLabel("#\(index + 1)", size: 10, weight: .bold, color: rankColor))
            let name = menuLabel(row.label, size: 12, weight: .bold, color: RelayTheme.text)
            name.lineBreakMode = .byTruncatingMiddle
            nameRow.addArrangedSubview(name)
            item.addArrangedSubview(nameRow)
            item.addArrangedSubview(menuLabel(
                "\(MenuValueFormatter.number(row.requests)) REQ / \(MenuValueFormatter.tokenCount(row.tokens)) TOKEN",
                size: 10,
                weight: .bold,
                color: RelayTheme.muted
            ))
            stack.addArrangedSubview(item)
        }
        return stack
    }

    private func chartColumn(rows: [UsageRankingRow], texts: TextBundle) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 5
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.widthAnchor.constraint(equalToConstant: 88).isActive = true
        let chart = ModelTokenSharePieChartView(
            rows: rows,
            colors: Self.rankColors,
            accessibilityLabel: "\(texts.topModel) \(texts.tokens)"
        ) { [weak self] selection in
            self?.chartDetail.stringValue = selection.map { "\($0.label) · \($0.percent)%" }
                ?? "\(texts.tokens.uppercased()) %"
        }
        chart.translatesAutoresizingMaskIntoConstraints = false
        chart.widthAnchor.constraint(equalToConstant: 82).isActive = true
        chart.heightAnchor.constraint(equalToConstant: 82).isActive = true
        stack.addArrangedSubview(chart)
        return stack
    }
}

private final class ModelTokenSharePieChartView: NSView {
    struct Selection {
        let label: String
        let percent: Int
    }

    private let rows: [UsageRankingRow]
    private let colors: [NSColor]
    private let onHover: (Selection?) -> Void
    private var hoveredIndex: Int?
    private var trackingArea: NSTrackingArea?

    init(
        rows: [UsageRankingRow],
        colors: [NSColor],
        accessibilityLabel: String,
        onHover: @escaping (Selection?) -> Void
    ) {
        self.rows = rows
        self.colors = colors
        self.onHover = onHover
        super.init(frame: .zero)
        identifier = NSUserInterfaceItemIdentifier("top-model-token-share-chart")
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(accessibilityLabel)
        setAccessibilityValue(accessibilitySummary)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let diameter = min(bounds.width, bounds.height) - 2
        let radius = diameter / 2
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let total = rows.reduce(0) { $0 + max($1.tokens, 0) }

        guard total > 0 else {
            drawEmpty(center: center, radius: radius)
            return
        }

        var startAngle: CGFloat = 90
        for (index, row) in rows.enumerated() where row.tokens > 0 {
            let sweep = CGFloat(row.tokens) / CGFloat(total) * 360
            let path = NSBezierPath()
            path.move(to: center)
            path.appendArc(
                withCenter: center,
                radius: radius,
                startAngle: startAngle,
                endAngle: startAngle - sweep,
                clockwise: true
            )
            path.close()
            colors[index % colors.count].setFill()
            path.fill()
            if index == hoveredIndex {
                RelayTheme.text.setStroke()
                path.lineWidth = 2
                path.stroke()
            }
            startAngle -= sweep
        }

        RelayTheme.background.withAlphaComponent(0.9).setStroke()
        let outline = NSBezierPath(ovalIn: NSRect(
            x: center.x - radius,
            y: center.y - radius,
            width: diameter,
            height: diameter
        ))
        outline.lineWidth = 1
        outline.stroke()

        if window?.firstResponder === self {
            RelayTheme.cyan.setStroke()
            let focusRing = NSBezierPath(ovalIn: bounds.insetBy(dx: 1, dy: 1))
            focusRing.lineWidth = 2
            focusRing.stroke()
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let nextArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(nextArea)
        trackingArea = nextArea
    }

    override func mouseMoved(with event: NSEvent) {
        selectSlice(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        selectSlice(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseExited(with event: NSEvent) {
        updateSelection(nil)
    }

    override func keyDown(with event: NSEvent) {
        let populatedIndices = rows.indices.filter { rows[$0].tokens > 0 }
        guard !populatedIndices.isEmpty else {
            super.keyDown(with: event)
            return
        }
        switch event.keyCode {
        case 123, 125:
            let current = hoveredIndex.flatMap { populatedIndices.firstIndex(of: $0) } ?? 0
            updateSelection(populatedIndices[(current - 1 + populatedIndices.count) % populatedIndices.count])
        case 124, 126:
            let current = hoveredIndex.flatMap { populatedIndices.firstIndex(of: $0) } ?? -1
            updateSelection(populatedIndices[(current + 1) % populatedIndices.count])
        case 53:
            updateSelection(nil)
        default:
            super.keyDown(with: event)
        }
    }

    override func becomeFirstResponder() -> Bool {
        needsDisplay = true
        return true
    }

    override func resignFirstResponder() -> Bool {
        updateSelection(nil)
        needsDisplay = true
        return true
    }

    private func selectSlice(at point: NSPoint) {
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let deltaX = point.x - center.x
        let deltaY = point.y - center.y
        let radius = (min(bounds.width, bounds.height) - 2) / 2
        guard hypot(deltaX, deltaY) <= radius else {
            updateSelection(nil)
            return
        }

        let total = rows.reduce(0) { $0 + max($1.tokens, 0) }
        guard total > 0 else {
            updateSelection(nil)
            return
        }
        let angle = atan2(deltaY, deltaX) * 180 / .pi
        let clockwiseOffset = (90 - angle).truncatingRemainder(dividingBy: 360)
        let normalizedOffset = clockwiseOffset >= 0 ? clockwiseOffset : clockwiseOffset + 360
        var endOffset: CGFloat = 0
        for (index, row) in rows.enumerated() where row.tokens > 0 {
            endOffset += CGFloat(row.tokens) / CGFloat(total) * 360
            if normalizedOffset <= endOffset {
                updateSelection(index)
                return
            }
        }
        updateSelection(nil)
    }

    private func updateSelection(_ index: Int?) {
        guard hoveredIndex != index else { return }
        hoveredIndex = index
        let selection = index.map(selection(at:))
        toolTip = selection.map { "\($0.label) · \($0.percent)%" }
        setAccessibilityValue(selection.map { "\($0.label) \($0.percent)%" } ?? accessibilitySummary)
        onHover(selection)
        needsDisplay = true
    }

    private func selection(at index: Int) -> Selection {
        let total = rows.reduce(0) { $0 + max($1.tokens, 0) }
        let percent = total > 0
            ? Int((Double(max(rows[index].tokens, 0)) / Double(total) * 100).rounded())
            : 0
        return Selection(label: rows[index].label, percent: percent)
    }

    private var accessibilitySummary: String {
        let total = rows.reduce(0) { $0 + max($1.tokens, 0) }
        guard total > 0 else { return "--" }
        return rows.map { row in
            let percent = Int((Double(max(row.tokens, 0)) / Double(total) * 100).rounded())
            return "\(row.label) \(percent)%"
        }.joined(separator: " / ")
    }

    private func drawEmpty(center: NSPoint, radius: CGFloat) {
        RelayTheme.raisedAlt.setFill()
        NSBezierPath(ovalIn: NSRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )).fill()
        let text = "--" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: RelayTheme.font(size: 10, weight: .bold),
            .foregroundColor: RelayTheme.muted
        ]
        let size = text.size(withAttributes: attributes)
        text.draw(at: NSPoint(x: center.x - size.width / 2, y: center.y - size.height / 2), withAttributes: attributes)
    }
}
