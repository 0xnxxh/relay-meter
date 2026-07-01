import AppKit

enum RelayTheme {
    static let background = NSColor(red: 0.055, green: 0.063, blue: 0.075, alpha: 1)
    static let raised = NSColor(red: 0.090, green: 0.102, blue: 0.122, alpha: 1)
    static let raisedAlt = NSColor(red: 0.120, green: 0.137, blue: 0.160, alpha: 1)
    static let line = NSColor(red: 0.365, green: 0.392, blue: 0.420, alpha: 1)
    static let text = NSColor(red: 0.925, green: 0.945, blue: 0.900, alpha: 1)
    static let muted = NSColor(red: 0.540, green: 0.605, blue: 0.590, alpha: 1)
    static let up = NSColor(red: 0.215, green: 0.900, blue: 0.515, alpha: 1)
    static let down = NSColor(red: 0.965, green: 0.220, blue: 0.360, alpha: 1)
    static let warn = NSColor(red: 0.990, green: 0.725, blue: 0.255, alpha: 1)
    static let accent = NSColor(red: 1.000, green: 0.810, blue: 0.255, alpha: 1)
    static let cyan = NSColor(red: 0.330, green: 0.790, blue: 0.950, alpha: 1)

    static func font(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        .monospacedSystemFont(ofSize: size, weight: weight)
    }

    static func healthColor(_ health: HealthState) -> NSColor {
        switch health {
        case .good: up
        case .idle: muted
        case .warn: warn
        case .bad: down
        }
    }

    static func applyWindowBackground(to view: NSView) {
        view.wantsLayer = true
        view.layer?.backgroundColor = background.cgColor
    }

    static func styleButton(
        _ button: NSButton,
        tint: NSColor = accent,
        fill: NSColor = background,
        isSelected: Bool = false,
        fontSize: CGFloat = 11
    ) {
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 0
        button.layer?.borderWidth = 1
        button.layer?.borderColor = tint.cgColor
        button.layer?.backgroundColor = (isSelected ? tint : fill).cgColor
        button.contentTintColor = isSelected ? background : tint
        button.font = font(size: fontSize, weight: .bold)
        button.attributedTitle = NSAttributedString(
            string: button.title.uppercased(),
            attributes: [.foregroundColor: isSelected ? background : tint, .font: font(size: fontSize, weight: .bold)]
        )
        button.attributedAlternateTitle = NSAttributedString(
            string: button.alternateTitle.uppercased(),
            attributes: [.foregroundColor: background, .font: font(size: fontSize, weight: .bold)]
        )
    }

    static func styleField(_ field: NSTextField) {
        field.font = font(size: 12, weight: .semibold)
        field.textColor = text
        field.drawsBackground = true
        field.backgroundColor = background
        field.isBezeled = false
        field.wantsLayer = true
        field.layer?.cornerRadius = 0
        field.layer?.borderWidth = 1
        field.layer?.borderColor = line.withAlphaComponent(0.85).cgColor
        field.layer?.backgroundColor = background.cgColor
        field.cell?.controlSize = .large
    }

}

final class RelayBackgroundView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        RelayTheme.applyWindowBackground(to: self)
    }

    required init?(coder: NSCoder) {
        nil
    }
}
