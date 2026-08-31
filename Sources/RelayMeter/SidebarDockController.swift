import AppKit

/// Owns the screen-edge dock panel and its side bubble.
///
/// Both panels copy the main menu panel's window configuration (`main.swift`): borderless,
/// non-activating, floating at `.popUpMenu` level so they stay visible without stealing focus.
@MainActor
final class SidebarDockController {
    private var dockPanel: NSPanel?
    private var bubblePanel: NSPanel?
    private var dockView: SidebarDockView?
    private var items: [DockGaugeItem] = []
    private var selectedIndex: Int?
    private var refreshedAt = Date()
    private var texts = TextBundle.forLanguage(.english)
    private var outsideClickMonitor: Any?
    private var isPresented = false
    private var edge: SidebarDockEdge = .right
    /// 0 = flush with the top of the visible frame, 1 = flush with the bottom.
    private var verticalOffset: Double = 0.5
    private var dragStartOrigin: NSPoint?

    /// Invoked by the bubble's "open panel" button.
    var onOpenPanel: (() -> Void)?
    /// Invoked after a drag settles so the new placement can be persisted.
    var onPlacementChanged: ((SidebarDockEdge, Double) -> Void)?

    func update(dashboard: UsageDashboardSnapshot?, texts: TextBundle, edge: SidebarDockEdge, verticalOffset: Double) {
        self.texts = texts
        self.edge = edge
        self.verticalOffset = min(max(verticalOffset, 0), 1)
        items = dashboard.map(SidebarDockModel.dockItems(from:)) ?? []
        refreshedAt = dashboard?.refreshedAt ?? Date()
        if let selectedIndex, selectedIndex >= items.count {
            self.selectedIndex = nil
            hideBubble()
        }
        guard isPresented else { return }
        rebuildDock()
        if let selectedIndex {
            showBubble(at: selectedIndex)
        }
    }

    func show() {
        isPresented = true
        rebuildDock()
        dockPanel?.orderFrontRegardless()
        installOutsideClickMonitor()
    }

    func hide() {
        isPresented = false
        hideBubble()
        dockPanel?.orderOut(nil)
        removeOutsideClickMonitor()
    }

    // MARK: - Dock

    private func rebuildDock() {
        guard !items.isEmpty else {
            dockPanel?.orderOut(nil)
            hideBubble()
            return
        }
        let panel = dockPanelIfNeeded()
        let drag = SidebarDockDragHandlers(
            began: { [weak self] in self?.beginDrag() },
            moved: { [weak self] delta in self?.moveDrag(by: delta) },
            ended: { [weak self] in self?.endDrag() }
        )
        let view = SidebarDockView(items: items, selectedIndex: selectedIndex, drag: drag) { [weak self] index in
            self?.toggleBubble(at: index)
        }
        let container = NSView(frame: NSRect(origin: .zero, size: view.frame.size))
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        panel.contentView = container
        panel.setContentSize(view.frame.size)
        dockView = view
        alignDockPanel()
        if isPresented {
            panel.orderFrontRegardless()
        }
    }

    private func dockPanelIfNeeded() -> NSPanel {
        if let dockPanel { return dockPanel }
        let panel = makePanel()
        dockPanel = panel
        return panel
    }

    private func alignDockPanel() {
        guard let panel = dockPanel, let screen = dockScreen() else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let x = edge == .right ? visible.maxX - size.width : visible.minX
        let travel = max(visible.height - size.height, 0)
        let y = visible.maxY - size.height - CGFloat(verticalOffset) * travel
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func dockScreen() -> NSScreen? {
        guard let panel = dockPanel else { return NSScreen.main }
        return panel.screen ?? NSScreen.main
    }

    // MARK: - Dragging

    private func beginDrag() {
        dragStartOrigin = dockPanel?.frame.origin
        hideBubble()
        selectedIndex = nil
    }

    private func moveDrag(by delta: NSPoint) {
        guard let panel = dockPanel, let dragStartOrigin else { return }
        panel.setFrameOrigin(NSPoint(x: dragStartOrigin.x + delta.x, y: dragStartOrigin.y + delta.y))
    }

    /// Snaps to whichever vertical edge the strip ended up nearest and persists the placement.
    private func endDrag() {
        defer { dragStartOrigin = nil }
        guard let panel = dockPanel, let screen = dockScreen() else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        edge = panel.frame.midX < visible.midX ? .left : .right
        let travel = max(visible.height - size.height, 0)
        if travel > 0 {
            let top = visible.maxY - size.height
            verticalOffset = Double(min(max((top - panel.frame.minY) / travel, 0), 1))
        } else {
            verticalOffset = 0
        }
        alignDockPanel()
        rebuildDock()
        onPlacementChanged?(edge, verticalOffset)
    }

    // MARK: - Bubble

    private func toggleBubble(at index: Int) {
        if selectedIndex == index {
            selectedIndex = nil
            hideBubble()
            rebuildDock()
            return
        }
        selectedIndex = index
        rebuildDock()
        showBubble(at: index)
    }

    private func showBubble(at index: Int) {
        guard index < items.count else { return }
        let panel = bubblePanelIfNeeded()
        let view = SidebarBubbleView(
            item: items[index],
            accent: SidebarDockView.accent(at: index),
            texts: texts,
            refreshedAt: refreshedAt,
            onOpenPanel: { [weak self] in
                self?.hideBubble()
                self?.selectedIndex = nil
                self?.rebuildDock()
                self?.onOpenPanel?()
            }
        )
        let container = NSView(frame: NSRect(origin: .zero, size: view.frame.size))
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        panel.contentView = container
        panel.setContentSize(view.frame.size)
        alignBubblePanel(at: index)
        panel.orderFrontRegardless()
    }

    private func bubblePanelIfNeeded() -> NSPanel {
        if let bubblePanel { return bubblePanel }
        let panel = makePanel()
        bubblePanel = panel
        return panel
    }

    private func alignBubblePanel(at index: Int) {
        guard
            let bubble = bubblePanel,
            let dock = dockPanel,
            let dockView,
            let screen = dockScreen()
        else { return }
        let visible = screen.visibleFrame
        let size = bubble.frame.size
        let gap: CGFloat = 8
        // The bubble always opens away from the screen edge the dock is parked on.
        let x = edge == .right ? dock.frame.minX - size.width - gap : dock.frame.maxX + gap
        let itemCenterY = dock.frame.maxY - dockView.itemCenterFromTop(index)
        var y = itemCenterY - size.height / 2
        y = min(max(y, visible.minY + gap), max(visible.maxY - size.height - gap, visible.minY + gap))
        let clampedX = min(max(x, visible.minX + gap), max(visible.maxX - size.width - gap, visible.minX + gap))
        bubble.setFrameOrigin(NSPoint(x: clampedX, y: y))
    }

    private func hideBubble() {
        bubblePanel?.orderOut(nil)
    }

    // MARK: - Windows

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.isOpaque = false
        panel.isReleasedWhenClosed = false
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        return panel
    }

    private func installOutsideClickMonitor() {
        removeOutsideClickMonitor()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            DispatchQueue.main.async {
                self?.closeBubbleIfClickIsOutside(event)
            }
        }
    }

    private func closeBubbleIfClickIsOutside(_ event: NSEvent) {
        guard selectedIndex != nil, let bubble = bubblePanel, bubble.isVisible else { return }
        let point = screenPoint(for: event)
        if bubble.frame.contains(point) { return }
        if let dockPanel, dockPanel.frame.contains(point) { return }
        selectedIndex = nil
        hideBubble()
        rebuildDock()
    }

    private func removeOutsideClickMonitor() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
    }

    private func screenPoint(for event: NSEvent) -> NSPoint {
        guard let window = event.window else { return event.locationInWindow }
        return window.convertPoint(toScreen: event.locationInWindow)
    }
}
