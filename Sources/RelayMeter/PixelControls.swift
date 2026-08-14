import AppKit

final class PixelTextField: NSTextField {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        cell = VerticallyCenteredTextFieldCell(textCell: "")
        isEditable = true
        isSelectable = true
        refusesFirstResponder = false
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        RelayTheme.background.setFill()
        bounds.fill()
        super.draw(dirtyRect)
        RelayTheme.line.withAlphaComponent(0.85).setStroke()
        NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5)).stroke()
    }

}

final class PixelSecureField: NSSecureTextField {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        cell = PixelSecureTextFieldCell(textCell: "")
        isEditable = true
        isSelectable = true
        refusesFirstResponder = false
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        RelayTheme.background.setFill()
        bounds.fill()
        super.draw(dirtyRect)
        RelayTheme.line.withAlphaComponent(0.85).setStroke()
        NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5)).stroke()
    }
}

private final class VerticallyCenteredTextFieldCell: NSTextFieldCell {
    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        let textSize = cellSize(forBounds: rect)
        let y = rect.origin.y + max(0, (rect.height - textSize.height) / 2)
        return NSRect(x: rect.origin.x + 7, y: y, width: rect.width - 14, height: textSize.height)
    }

    override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
        super.edit(withFrame: drawingRect(forBounds: rect), in: controlView, editor: textObj, delegate: delegate, event: event)
    }

    override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        super.select(withFrame: drawingRect(forBounds: rect), in: controlView, editor: textObj, delegate: delegate, start: selStart, length: selLength)
    }
}

private final class PixelSecureTextFieldCell: NSSecureTextFieldCell {
    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        let textSize = cellSize(forBounds: rect)
        let y = rect.origin.y + max(0, (rect.height - textSize.height) / 2)
        return NSRect(x: rect.origin.x + 7, y: y, width: rect.width - 14, height: textSize.height)
    }

    override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
        super.edit(withFrame: drawingRect(forBounds: rect), in: controlView, editor: textObj, delegate: delegate, event: event)
    }

    override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        super.select(withFrame: drawingRect(forBounds: rect), in: controlView, editor: textObj, delegate: delegate, start: selStart, length: selLength)
    }
}

final class PixelPopupButton: NSButton {
    struct Item {
        let title: String
        let representedObject: Any?
    }

    private var items: [Item] = []
    private var selectedIndex = 0
    private var popupWindow: NSWindow?
    private var localClickMonitor: Any?
    private var globalClickMonitor: Any?

    var selectedRepresentedObject: Any? {
        guard items.indices.contains(selectedIndex) else { return nil }
        return items[selectedIndex].representedObject
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        applyPixelStyle()
    }

    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        removeClickMonitors()
    }

    func removeAllItems() {
        items.removeAll()
        selectedIndex = 0
        title = ""
    }

    func addItem(title: String, representedObject: Any?) {
        items.append(Item(title: title, representedObject: representedObject))
        if items.count == 1 {
            selectIndex(0, sendAction: false)
        }
    }

    func selectRepresentedObject(_ value: String) {
        if let index = items.firstIndex(where: { ($0.representedObject as? String) == value }) {
            selectIndex(index, sendAction: false)
        }
    }

    func applyPixelStyle() {
        isBordered = false
        font = RelayTheme.font(size: 12, weight: .bold)
        contentTintColor = RelayTheme.text
        wantsLayer = true
        layer?.cornerRadius = 0
        layer?.borderWidth = 1
        layer?.borderColor = RelayTheme.line.cgColor
        layer?.backgroundColor = RelayTheme.background.cgColor
        alignment = .left
    }

    override func draw(_ dirtyRect: NSRect) {
        RelayTheme.background.setFill()
        bounds.fill()
        super.draw(dirtyRect)
        RelayTheme.line.setStroke()
        NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5)).stroke()
        drawChevron()
    }

    private func selectIndex(_ index: Int, sendAction: Bool) {
        guard items.indices.contains(index) else { return }
        selectedIndex = index
        attributedTitle = NSAttributedString(
            string: "  \(items[index].title)",
            attributes: [.foregroundColor: RelayTheme.text, .font: RelayTheme.font(size: 12, weight: .bold)]
        )
        needsDisplay = true
        if sendAction, let target, let action {
            NSApp.sendAction(action, to: target, from: self)
        }
    }

    override func mouseDown(with event: NSEvent) {
        togglePopup()
    }

    override func performClick(_ sender: Any?) {
        togglePopup()
    }

    private func togglePopup() {
        popupWindow == nil ? showPopup() : closePopup()
    }

    private func showPopup() {
        guard let window, !items.isEmpty else { return }
        let rowHeight: CGFloat = 34
        let width = bounds.width
        let height = rowHeight * CGFloat(items.count)
        let screenRect = window.convertToScreen(convert(bounds, to: nil))
        let content = RelayBackgroundView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        var previous: NSView?
        for (index, item) in items.enumerated() {
            let button = NSButton(title: item.title, target: self, action: #selector(selectPopupItem(_:)))
            button.tag = index
            button.translatesAutoresizingMaskIntoConstraints = false
            RelayTheme.styleButton(button, tint: index == selectedIndex ? RelayTheme.accent : RelayTheme.line, isSelected: index == selectedIndex, fontSize: 12)
            content.addSubview(button)
            NSLayoutConstraint.activate([
                button.leadingAnchor.constraint(equalTo: content.leadingAnchor),
                button.trailingAnchor.constraint(equalTo: content.trailingAnchor),
                button.heightAnchor.constraint(equalToConstant: rowHeight)
            ])
            if let previous {
                button.topAnchor.constraint(equalTo: previous.bottomAnchor).isActive = true
            } else {
                button.topAnchor.constraint(equalTo: content.topAnchor).isActive = true
            }
            previous = button
        }

        let popup = NSWindow(
            contentRect: NSRect(x: screenRect.minX, y: screenRect.minY - height, width: width, height: height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        popup.contentView = content
        popup.backgroundColor = .clear
        popup.isOpaque = false
        popup.hasShadow = true
        popup.level = .popUpMenu
        popup.orderFront(nil)
        popupWindow = popup
        installClickMonitors()
    }

    @objc private func selectPopupItem(_ sender: NSButton) {
        selectIndex(sender.tag, sendAction: true)
        closePopup()
    }

    private func closePopup() {
        popupWindow?.orderOut(nil)
        popupWindow = nil
        removeClickMonitors()
    }

    private func installClickMonitors() {
        removeClickMonitors()
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self else { return event }
            if !self.eventHitsPopupOrButton(event) {
                self.closePopup()
            }
            return event
        }
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            DispatchQueue.main.async { self?.closePopup() }
        }
    }

    private func removeClickMonitors() {
        if let localClickMonitor {
            NSEvent.removeMonitor(localClickMonitor)
            self.localClickMonitor = nil
        }
        if let globalClickMonitor {
            NSEvent.removeMonitor(globalClickMonitor)
            self.globalClickMonitor = nil
        }
    }

    private func eventHitsPopupOrButton(_ event: NSEvent) -> Bool {
        if event.window === window {
            let point = convert(event.locationInWindow, from: nil)
            return bounds.contains(point)
        }
        if event.window === popupWindow {
            return true
        }
        return false
    }

    private func drawChevron() {
        RelayTheme.text.setStroke()
        let path = NSBezierPath()
        let midX = bounds.maxX - 18
        let midY = bounds.midY
        path.move(to: NSPoint(x: midX - 4, y: midY + 2))
        path.line(to: NSPoint(x: midX, y: midY - 2))
        path.line(to: NSPoint(x: midX + 4, y: midY + 2))
        path.lineWidth = 2
        path.stroke()
    }
}
