import AppKit

class RoundedPanelView: NSView {
    init(accentColor: NSColor, fillAlpha: CGFloat) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 1
        layer?.borderColor = accentColor.withAlphaComponent(0.18).cgColor
        layer?.backgroundColor = accentColor.withAlphaComponent(fillAlpha).cgColor
    }

    required init?(coder: NSCoder) {
        nil
    }
}

final class StatusDotView: NSView {
    init(color: NSColor) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 5
        layer?.backgroundColor = color.cgColor
    }

    required init?(coder: NSCoder) {
        nil
    }
}

func menuHealthColor(_ health: HealthState) -> NSColor {
    switch health {
    case .good: return .systemGreen
    case .idle: return .systemGray
    case .warn: return .systemOrange
    case .bad: return .systemRed
    }
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
    icon.widthAnchor.constraint(equalToConstant: 8).isActive = true
    icon.heightAnchor.constraint(equalToConstant: 8).isActive = true
    row.addArrangedSubview(icon)
    row.addArrangedSubview(menuLabel(title, size: 12, weight: .semibold, color: .labelColor))
    return row
}

func menuLabel(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSTextField {
    let field = NSTextField(labelWithString: text)
    field.font = .systemFont(ofSize: size, weight: weight)
    field.textColor = color
    field.maximumNumberOfLines = 1
    field.lineBreakMode = .byTruncatingTail
    return field
}
