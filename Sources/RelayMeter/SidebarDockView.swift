import AppKit

/// Circular share gauge drawn in the same square-edged pixel language as the rest of the menu.
///
/// The centre holds the adapter's initial rather than a platform glyph: one ring is one adapter,
/// so two adapters on the same platform must still be tellable apart at a glance.
final class RingGaugeView: NSView {
    private let share: Double
    private let accent: NSColor
    private let initial: String
    private let isEmpty: Bool

    init(share: Double, accent: NSColor, initial: String, isEmpty: Bool) {
        self.share = min(max(share, 0), 1)
        self.accent = accent
        self.initial = initial
        self.isEmpty = isEmpty
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let lineWidth: CGFloat = 3
        let diameter = min(bounds.width, bounds.height) - lineWidth
        guard diameter > 0 else { return }
        let radius = diameter / 2
        let center = NSPoint(x: bounds.midX, y: bounds.midY)

        let track = NSBezierPath()
        track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        track.lineWidth = lineWidth
        (isEmpty ? RelayTheme.raisedAlt : RelayTheme.line.withAlphaComponent(0.45)).setStroke()
        track.stroke()

        if isEmpty {
            drawEmptyMark(center: center)
            return
        }

        if share > 0 {
            let sweep = CGFloat(share) * 360
            let progress = NSBezierPath()
            progress.appendArc(
                withCenter: center,
                radius: radius,
                startAngle: 90,
                endAngle: 90 - sweep,
                clockwise: true
            )
            progress.lineWidth = lineWidth
            progress.lineCapStyle = .butt
            accent.setStroke()
            progress.stroke()
        }

        let inset = floor(diameter * 0.62)
        drawInitial(in: NSRect(
            x: center.x - inset / 2,
            y: center.y - inset / 2,
            width: inset,
            height: inset
        ))
    }

    /// Shrinks the initial until it clears the ring stroke; CJK glyphs are much wider than Latin ones.
    private func drawInitial(in rect: NSRect) {
        guard !initial.isEmpty else { return }
        let text = initial as NSString
        var size = floor(rect.height)
        var attributes: [NSAttributedString.Key: Any] = [:]
        var textSize = NSSize.zero
        while size > 7 {
            attributes = [
                .font: RelayTheme.font(size: size, weight: .bold),
                .foregroundColor: accent
            ]
            textSize = text.size(withAttributes: attributes)
            if textSize.width <= rect.width && textSize.height <= rect.height { break }
            size -= 1
        }
        text.draw(
            at: NSPoint(x: rect.midX - textSize.width / 2, y: rect.midY - textSize.height / 2),
            withAttributes: attributes
        )
    }

    private func drawEmptyMark(center: NSPoint) {
        let text = "--" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: RelayTheme.font(size: 10, weight: .bold),
            .foregroundColor: RelayTheme.muted
        ]
        let size = text.size(withAttributes: attributes)
        text.draw(
            at: NSPoint(x: center.x - size.width / 2, y: center.y - size.height / 2),
            withAttributes: attributes
        )
    }
}

/// Press-and-drag plumbing shared by the dock strip and its rows.
///
/// A press that moves past `dragThreshold` becomes a window drag; anything shorter is a click, so
/// the whole strip can be repositioned by grabbing any part of it without losing ring selection.
class SidebarDockDraggableView: NSView {
    private static let dragThreshold: CGFloat = 3

    private let drag: SidebarDockDragHandlers
    private var dragAnchor: NSPoint?
    private var didDrag = false

    init(drag: SidebarDockDragHandlers) {
        self.drag = drag
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        nil
    }

    /// Invoked on mouse-up when the press never became a drag.
    func handleClick() {}

    override func mouseDown(with event: NSEvent) {
        dragAnchor = NSEvent.mouseLocation
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragAnchor else { return }
        let current = NSEvent.mouseLocation
        let delta = NSPoint(x: current.x - dragAnchor.x, y: current.y - dragAnchor.y)
        if !didDrag {
            guard hypot(delta.x, delta.y) > Self.dragThreshold else { return }
            didDrag = true
            drag.began()
        }
        drag.moved(delta)
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            dragAnchor = nil
            didDrag = false
        }
        if didDrag {
            drag.ended()
        } else {
            handleClick()
        }
    }
}

/// Drag callbacks the dock strip forwards to its window controller.
struct SidebarDockDragHandlers {
    let began: () -> Void
    /// Screen-space offset from where the drag started.
    let moved: (NSPoint) -> Void
    let ended: () -> Void

    static let inert = SidebarDockDragHandlers(began: {}, moved: { _ in }, ended: {})
}

/// One dock row: gauge plus its token volume.
final class SidebarDockItemView: SidebarDockDraggableView {
    let item: DockGaugeItem
    private let index: Int
    private let onSelect: (Int) -> Void
    private var trackingArea: NSTrackingArea?
    private var isHighlighted = false

    init(
        item: DockGaugeItem,
        index: Int,
        accent: NSColor,
        isSelected: Bool,
        drag: SidebarDockDragHandlers,
        onSelect: @escaping (Int) -> Void
    ) {
        self.item = item
        self.index = index
        self.onSelect = onSelect
        super.init(drag: drag)
        identifier = NSUserInterfaceItemIdentifier("dock-item-\(index)")
        isHighlighted = isSelected
        wantsLayer = true
        layer?.backgroundColor = (isSelected ? RelayTheme.raisedAlt : NSColor.clear).cgColor
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("\(item.name) \(MenuValueFormatter.percent(item.share))")

        let ring = RingGaugeView(
            share: item.share,
            accent: accent,
            initial: SidebarDockView.initial(for: item.name),
            isEmpty: item.scope.totalTokens <= 0
        )
        ring.translatesAutoresizingMaskIntoConstraints = false
        let tokensLabel = menuLabel(
            item.scope.totalTokens > 0 ? MenuValueFormatter.tokenCount(item.scope.totalTokens) : "--",
            size: 10,
            weight: .bold,
            color: item.scope.totalTokens > 0 ? RelayTheme.text : RelayTheme.muted
        )
        tokensLabel.alignment = .center
        tokensLabel.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [ring, tokensLabel])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            ring.widthAnchor.constraint(equalToConstant: SidebarDockView.Layout.ringDiameter),
            ring.heightAnchor.constraint(equalToConstant: SidebarDockView.Layout.ringDiameter),
            tokensLabel.widthAnchor.constraint(equalToConstant: SidebarDockView.Layout.itemWidth),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        toolTip = "\(item.name) · \(MenuValueFormatter.percent(item.share)) · \(MenuValueFormatter.tokenCount(item.scope.totalTokens))"
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let nextArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(nextArea)
        trackingArea = nextArea
    }

    override func mouseEntered(with event: NSEvent) {
        guard !isHighlighted else { return }
        layer?.backgroundColor = RelayTheme.raisedAlt.withAlphaComponent(0.6).cgColor
    }

    override func mouseExited(with event: NSEvent) {
        guard !isHighlighted else { return }
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    override func handleClick() {
        onSelect(index)
    }
}

/// Vertical strip parked against a screen edge, one ring per adapter.
final class SidebarDockView: SidebarDockDraggableView {
    enum Layout {
        static let itemWidth: CGFloat = 52
        static let ringDiameter: CGFloat = 34
        static let labelHeight: CGFloat = 14
        static let labelSpacing: CGFloat = 4
        static let horizontalPadding: CGFloat = 8
        static let verticalPadding: CGFloat = 10
        static let spacing: CGFloat = 12
        static var width: CGFloat { itemWidth + horizontalPadding * 2 }
        static var itemHeight: CGFloat { ringDiameter + labelSpacing + labelHeight }
    }

    static let accents: [NSColor] = [RelayTheme.accent, RelayTheme.cyan, RelayTheme.up, RelayTheme.warn]

    /// First grapheme of the adapter name, uppercased for Latin scripts and left alone for CJK.
    static func initial(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "?" }
        return String(first).uppercased()
    }

    static func accent(at index: Int) -> NSColor {
        accents[index % accents.count]
    }

    let items: [DockGaugeItem]

    init(
        items: [DockGaugeItem],
        selectedIndex: Int?,
        drag: SidebarDockDragHandlers = .inert,
        onSelect: @escaping (Int) -> Void
    ) {
        self.items = items
        super.init(drag: drag)
        identifier = NSUserInterfaceItemIdentifier("sidebar-dock")
        wantsLayer = true
        layer?.cornerRadius = 0
        layer?.borderWidth = 1
        layer?.borderColor = RelayTheme.line.cgColor
        layer?.backgroundColor = RelayTheme.raised.cgColor

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = Layout.spacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        for (index, item) in items.enumerated() {
            let row = SidebarDockItemView(
                item: item,
                index: index,
                accent: Self.accent(at: index),
                isSelected: index == selectedIndex,
                drag: drag,
                onSelect: onSelect
            )
            row.translatesAutoresizingMaskIntoConstraints = false
            row.widthAnchor.constraint(equalToConstant: Layout.itemWidth).isActive = true
            row.heightAnchor.constraint(equalToConstant: Layout.itemHeight).isActive = true
            stack.addArrangedSubview(row)
        }
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: Layout.verticalPadding),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Layout.verticalPadding),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.horizontalPadding),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.horizontalPadding),
            widthAnchor.constraint(equalToConstant: Layout.width)
        ])
        layoutSubtreeIfNeeded()
        setFrameSize(NSSize(width: Layout.width, height: ceil(fittingSize.height)))
    }

    required init?(coder: NSCoder) {
        nil
    }

    /// Center of item `index` measured from the dock's top edge, used to align the bubble.
    func itemCenterFromTop(_ index: Int) -> CGFloat {
        Layout.verticalPadding
            + CGFloat(index) * (Layout.itemHeight + Layout.spacing)
            + Layout.itemHeight / 2
    }
}

/// A labelled progress row inside the dock bubble.
final class DockMetricRowView: NSView {
    init(title: String, share: Double, valueText: String, trailingText: String, accent: NSColor, width: CGFloat) {
        super.init(frame: .zero)
        let titleLabel = menuLabel(title, size: 11, weight: .semibold, color: RelayTheme.text)
        let bar = DockProgressBarView(share: share, accent: accent)
        bar.translatesAutoresizingMaskIntoConstraints = false
        let valueLabel = menuLabel(valueText, size: 11, weight: .bold, color: RelayTheme.text)
        let trailingLabel = menuLabel(trailingText, size: 11, weight: .regular, color: RelayTheme.muted)

        let footer = NSStackView(views: [valueLabel, NSView(), trailingLabel])
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.spacing = 6

        let stack = NSStackView(views: [titleLabel, bar, footer])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            bar.widthAnchor.constraint(equalToConstant: width),
            bar.heightAnchor.constraint(equalToConstant: 6),
            footer.widthAnchor.constraint(equalToConstant: width)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }
}

private final class DockProgressBarView: NSView {
    private let share: Double
    private let accent: NSColor

    init(share: Double, accent: NSColor) {
        self.share = min(max(share, 0), 1)
        self.accent = accent
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        RelayTheme.raisedAlt.setFill()
        NSBezierPath(rect: bounds).fill()
        guard share > 0 else { return }
        accent.setFill()
        NSBezierPath(rect: NSRect(
            x: bounds.minX,
            y: bounds.minY,
            width: floor(bounds.width * CGFloat(share)),
            height: bounds.height
        )).fill()
    }
}

/// Compact summary shown beside the dock when a ring is selected.
final class SidebarBubbleView: NSView {
    enum Layout {
        static let width: CGFloat = 300
        static let padding: CGFloat = 14
        static var contentWidth: CGFloat { width - padding * 2 }
    }

    init(
        item: DockGaugeItem,
        accent: NSColor,
        texts: TextBundle,
        refreshedAt: Date,
        onOpenPanel: @escaping () -> Void
    ) {
        super.init(frame: .zero)
        identifier = NSUserInterfaceItemIdentifier("sidebar-bubble")
        wantsLayer = true
        layer?.cornerRadius = 0
        layer?.borderWidth = 1
        layer?.borderColor = accent.cgColor
        layer?.backgroundColor = RelayTheme.raised.cgColor

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        // Echo the dock ring instead of a platform glyph so the bubble reads as "this ring, expanded".
        let titleRing = RingGaugeView(
            share: item.share,
            accent: accent,
            initial: SidebarDockView.initial(for: item.name),
            isEmpty: item.scope.totalTokens <= 0
        )
        titleRing.translatesAutoresizingMaskIntoConstraints = false
        titleRing.widthAnchor.constraint(equalToConstant: 22).isActive = true
        titleRing.heightAnchor.constraint(equalToConstant: 22).isActive = true
        let titleRow = NSStackView(views: [
            titleRing,
            menuLabel(item.name.uppercased(), size: 12, weight: .bold, color: RelayTheme.accent)
        ])
        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY
        titleRow.spacing = 7
        stack.addArrangedSubview(titleRow)

        stack.addArrangedSubview(DockMetricRowView(
            title: texts.dockTokenShare,
            share: item.share,
            valueText: MenuValueFormatter.percent(item.share),
            trailingText: "\(MenuValueFormatter.tokenCount(item.scope.totalTokens)) \(texts.tokenUnit)",
            accent: accent,
            width: Layout.contentWidth
        ))

        stack.addArrangedSubview(DockMetricRowView(
            title: texts.successRate,
            share: item.scope.successRate,
            valueText: MenuValueFormatter.percent(item.scope.successRate),
            trailingText: "\(MenuValueFormatter.compact(item.scope.totalRequests)) \(texts.requests)",
            accent: item.scope.failureCount > 0 ? RelayTheme.warn : RelayTheme.up,
            width: Layout.contentWidth
        ))

        let modelShares = SidebarDockModel.modelShares(in: item)
        if modelShares.isEmpty {
            stack.addArrangedSubview(menuLabel(
                "\(texts.topModel): --",
                size: 11,
                weight: .regular,
                color: RelayTheme.muted
            ))
        } else {
            stack.addArrangedSubview(menuLabel(
                texts.topModel.uppercased(),
                size: 10,
                weight: .bold,
                color: RelayTheme.muted
            ))
            for (offset, entry) in modelShares.enumerated() {
                let row = DockMetricRowView(
                    title: entry.row.label,
                    share: entry.share,
                    valueText: MenuValueFormatter.percent(entry.share),
                    trailingText: "\(MenuValueFormatter.tokenCount(entry.row.tokens)) \(texts.tokenUnit)",
                    accent: SidebarDockView.accent(at: offset),
                    width: Layout.contentWidth
                )
                row.identifier = NSUserInterfaceItemIdentifier("bubble-model-row-\(offset)")
                stack.addArrangedSubview(row)
            }
        }

        let updated = DateFormatter.localizedString(from: refreshedAt, dateStyle: .none, timeStyle: .medium)
        stack.addArrangedSubview(menuLabel(
            "\(texts.updated) \(updated)",
            size: 10,
            weight: .regular,
            color: RelayTheme.muted
        ))

        let openButton = NSButton(title: texts.dockOpenPanel, target: nil, action: nil)
        RelayTheme.styleButton(openButton)
        openButton.identifier = NSUserInterfaceItemIdentifier("bubble-open-panel")
        openButton.translatesAutoresizingMaskIntoConstraints = false
        let handler = ButtonActionHandler(action: onOpenPanel)
        openButton.target = handler
        openButton.action = #selector(ButtonActionHandler.invoke)
        actionHandler = handler
        stack.addArrangedSubview(openButton)

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: Layout.padding),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Layout.padding),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.padding),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.padding),
            widthAnchor.constraint(equalToConstant: Layout.width),
            openButton.heightAnchor.constraint(equalToConstant: 24),
            openButton.widthAnchor.constraint(equalToConstant: Layout.contentWidth)
        ])
        layoutSubtreeIfNeeded()
        setFrameSize(NSSize(width: Layout.width, height: ceil(fittingSize.height)))
    }

    required init?(coder: NSCoder) {
        nil
    }

    private var actionHandler: ButtonActionHandler?
}

/// Keeps a closure alive as an NSButton target; the bubble is rebuilt wholesale on every render.
final class ButtonActionHandler: NSObject {
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    @objc func invoke() {
        action()
    }
}
