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

/// Compact 5x5 pixel glyph used by menu cards (same visual language as status dots).
enum MenuPixelIconKind {
    case traffic
    case tokens
    case latency
    case recent
    case ranking
    case trend
    case error
    case status

    /// Row-major 5x5 mask; 1 fills a pixel cell.
    var cells: [UInt8] {
        switch self {
        case .status:
            // Diamond spark (legacy status mark)
            return [
                0, 1, 1, 1, 0,
                1, 0, 1, 0, 1,
                1, 1, 1, 1, 1,
                1, 0, 1, 0, 1,
                0, 1, 1, 1, 0
            ]
        case .traffic:
            // Rising activity bars
            return [
                0, 0, 0, 0, 1,
                0, 0, 0, 1, 1,
                0, 0, 1, 1, 1,
                0, 1, 1, 1, 1,
                1, 1, 1, 1, 1
            ]
        case .tokens:
            // Stacked token chips
            return [
                0, 1, 1, 1, 0,
                1, 0, 0, 0, 1,
                0, 1, 1, 1, 0,
                1, 0, 0, 0, 1,
                0, 1, 1, 1, 0
            ]
        case .latency:
            // Clock face with hands
            return [
                0, 1, 1, 1, 0,
                1, 0, 1, 0, 1,
                1, 0, 1, 1, 1,
                1, 0, 0, 0, 1,
                0, 1, 1, 1, 0
            ]
        case .recent:
            // Lightning bolt (recent burst)
            return [
                0, 0, 1, 1, 0,
                0, 1, 1, 0, 0,
                1, 1, 1, 1, 1,
                0, 0, 1, 1, 0,
                0, 1, 1, 0, 0
            ]
        case .ranking:
            // Rank podium bars (#1 center tall, #2 left, #3 right)
            return [
                0, 0, 1, 0, 0,
                0, 1, 1, 0, 0,
                0, 1, 1, 0, 1,
                1, 1, 1, 1, 1,
                1, 1, 1, 1, 1
            ]
        case .trend:
            // Upward trend steps
            return [
                0, 0, 0, 0, 1,
                0, 0, 0, 1, 1,
                0, 0, 1, 0, 1,
                0, 1, 0, 0, 1,
                1, 0, 0, 0, 1
            ]
        case .error:
            // X mark
            return [
                1, 0, 0, 0, 1,
                0, 1, 0, 1, 0,
                0, 0, 1, 0, 0,
                0, 1, 0, 1, 0,
                1, 0, 0, 0, 1
            ]
        }
    }
}

final class MenuPixelIconView: NSView {
    private let color: NSColor
    private let kind: MenuPixelIconKind

    init(kind: MenuPixelIconKind, color: NSColor) {
        self.kind = kind
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
        let columns = 5
        let rows = 5
        let cells = kind.cells
        let side = min(bounds.width, bounds.height)
        let gap = max(1, floor(side / 18))
        let cell = max(1, floor((side - gap * CGFloat(columns - 1)) / CGFloat(columns)))
        let totalW = cell * CGFloat(columns) + gap * CGFloat(columns - 1)
        let totalH = cell * CGFloat(rows) + gap * CGFloat(rows - 1)
        let originX = bounds.minX + floor((bounds.width - totalW) / 2)
        let originY = bounds.minY + floor((bounds.height - totalH) / 2)

        for row in 0..<rows {
            for column in 0..<columns {
                let index = row * columns + column
                guard index < cells.count, cells[index] != 0 else { continue }
                let x = originX + CGFloat(column) * (cell + gap)
                let y = originY + CGFloat(rows - 1 - row) * (cell + gap)
                NSBezierPath(rect: NSRect(x: x, y: y, width: cell, height: cell)).fill()
            }
        }
    }
}

/// Legacy 3x3 diamond used for health / legend markers.
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

func menuIconTitle(_ title: String, accent: NSColor, icon: MenuPixelIconKind = .status) -> NSView {
    let row = NSStackView()
    row.orientation = .horizontal
    row.alignment = .centerY
    row.spacing = 7
    let mark = MenuPixelIconView(kind: icon, color: accent)
    mark.translatesAutoresizingMaskIntoConstraints = false
    mark.widthAnchor.constraint(equalToConstant: 13).isActive = true
    mark.heightAnchor.constraint(equalToConstant: 13).isActive = true
    row.addArrangedSubview(mark)
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
