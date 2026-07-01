import AppKit

class RoundedPanelView: NSView {
    init(accentColor: NSColor, fillAlpha: CGFloat) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 0
        layer?.borderWidth = 1
        layer?.borderColor = accentColor.cgColor
        layer?.backgroundColor = RelayTheme.raised.withAlphaComponent(max(fillAlpha, 0.92)).cgColor
    }

    required init?(coder: NSCoder) {
        nil
    }
}

final class StatusDotView: NSView {
    private let color: NSColor

    init(color: NSColor) {
        self.color = color
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        color.setFill()
        let cell: CGFloat = max(2, floor(min(bounds.width, bounds.height) / 3.8))
        let gap: CGFloat = max(1, floor(cell / 3))
        let cells = [1, 2, 3, 5, 7, 9, 10, 11]
        for index in cells {
            let row = index / 3
            let column = index % 3
            let x = bounds.minX + CGFloat(column) * (cell + gap)
            let y = bounds.maxY - CGFloat(row + 1) * cell - CGFloat(row) * gap
            NSBezierPath(rect: NSRect(x: x, y: y, width: cell, height: cell)).fill()
        }
    }
}

func menuHealthColor(_ health: HealthState) -> NSColor {
    RelayTheme.healthColor(health)
}

enum MenuValueFormatter {
    static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    static func number(_ value: Int) -> String {
        NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
    }

    static func compact(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return String(value)
    }

    static func duration(ms value: Int) -> String {
        if value < 1_000 {
            return "\(value) ms"
        }
        if value < 60_000 {
            return String(format: "%.1f s", Double(value) / 1_000)
        }
        if value < 3_600_000 {
            return String(format: "%.1f min", Double(value) / 60_000)
        }
        return String(format: "%.1f h", Double(value) / 3_600_000)
    }
}

func menuIconTitle(_ title: String, accent: NSColor) -> NSView {
    let row = NSStackView()
    row.orientation = .horizontal
    row.alignment = .centerY
    row.spacing = 7
    let icon = StatusDotView(color: accent)
    icon.translatesAutoresizingMaskIntoConstraints = false
    icon.widthAnchor.constraint(equalToConstant: 13).isActive = true
    icon.heightAnchor.constraint(equalToConstant: 13).isActive = true
    row.addArrangedSubview(icon)
    row.addArrangedSubview(menuLabel(title.uppercased(), size: 12, weight: .bold, color: RelayTheme.accent))
    return row
}

func menuLabel(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSTextField {
    let field = NSTextField(labelWithString: text)
    field.font = RelayTheme.font(size: size, weight: weight)
    field.textColor = color
    field.maximumNumberOfLines = 1
    field.lineBreakMode = .byTruncatingTail
    return field
}
