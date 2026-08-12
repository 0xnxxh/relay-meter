// Hallmark · activity heatmaps · RelayTheme/AppKit · pre-emit: P5 H5 E4 S5 R5 V5
import AppKit

enum UsageActivityDisplayMode: CaseIterable {
    case calendarYear
    case rollingYear

    func dataset(from source: UsageActivityDataset, calendar: Calendar = .current) -> UsageActivityDataset {
        switch self {
        case .calendarYear:
            let reference = source.bounds.end
            guard let start = calendar.date(from: calendar.dateComponents([.year], from: reference)) else {
                return source
            }
            return source.clipped(to: UsageDateBounds(start: start, end: reference), calendar: calendar)
        case .rollingYear:
            return source
        }
    }
}

final class ActivityWindowController: NSWindowController {
    private let dashboard: UsageDashboardSnapshot
    private let texts: TextBundle
    private var selectedSourceID: String
    private var selectedMetric = UsageActivityMetric.requests
    private var selectedDisplayMode = UsageActivityDisplayMode.calendarYear
    private var sourceIDs: [String] = []
    private let contentStack = NSStackView()
    private let detailLabel = menuLabel("--", size: 11, weight: .bold, color: RelayTheme.text)

    init(dashboard: UsageDashboardSnapshot, selectedSourceID: String, texts: TextBundle) {
        self.dashboard = dashboard
        self.texts = texts
        self.selectedSourceID = selectedSourceID
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = texts.activity
        window.isReleasedWhenClosed = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.backgroundColor = RelayTheme.background
        window.isOpaque = false
        window.center()
        super.init(window: window)
        buildWindow()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildWindow() {
        guard let window else { return }
        let root = RelayBackgroundView()
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 12
        contentStack.edgeInsets = NSEdgeInsets(top: 34, left: 20, bottom: 18, right: 20)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: root.topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: root.bottomAnchor)
        ])
        window.contentView = root
        rebuildContent()
    }

    private func rebuildContent() {
        contentStack.arrangedSubviews.forEach { view in
            contentStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 12
        let title = menuLabel(texts.activity, size: 18, weight: .black, color: RelayTheme.text)
        header.addArrangedSubview(title)
        header.addArrangedSubview(NSView())
        header.addArrangedSubview(sourcePopup())
        header.addArrangedSubview(displayModeTabs())
        header.addArrangedSubview(metricTabs())
        header.translatesAutoresizingMaskIntoConstraints = false
        header.widthAnchor.constraint(equalToConstant: 780).isActive = true
        contentStack.addArrangedSubview(header)

        let dataset = selectedDisplayMode.dataset(from: selectedSnapshot().activity)
        let summary = activitySummary(dataset)
        summary.maximumNumberOfLines = 2
        summary.lineBreakMode = .byWordWrapping
        summary.widthAnchor.constraint(equalToConstant: 780).isActive = true
        contentStack.addArrangedSubview(summary)

        let heatmap = ActivityHeatmapView(
            dataset: dataset,
            metric: selectedMetric,
            layout: .calendar
        ) { [weak self] day in
            self?.detailLabel.stringValue = self?.detail(day) ?? "--"
        }
        heatmap.translatesAutoresizingMaskIntoConstraints = false
        heatmap.widthAnchor.constraint(equalToConstant: 780).isActive = true
        heatmap.heightAnchor.constraint(equalToConstant: 136).isActive = true
        heatmap.setAccessibilityLabel(texts.activity)
        contentStack.addArrangedSubview(heatmap)

        let footer = NSStackView()
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.spacing = 8
        footer.addArrangedSubview(ActivityLegendView(texts: texts, includeUnknown: true))
        footer.addArrangedSubview(NSView())
        detailLabel.stringValue = detail(dataset.days.last)
        detailLabel.alignment = .right
        footer.addArrangedSubview(detailLabel)
        footer.translatesAutoresizingMaskIntoConstraints = false
        footer.widthAnchor.constraint(equalToConstant: 780).isActive = true
        contentStack.addArrangedSubview(footer)
    }

    private func sourcePopup() -> PixelPopupButton {
        let sources = [(UsageDashboardSnapshot.aggregateSourceID, texts.allAdapters)] + dashboard.adapters.map { ($0.sourceID, $0.sourceName) }
        sourceIDs = sources.map(\.0)
        let popup = PixelPopupButton(frame: .zero)
        for source in sources {
            popup.addItem(title: source.1, representedObject: source.0)
        }
        popup.selectRepresentedObject(selectedSourceID)
        popup.target = self
        popup.action = #selector(sourceChanged(_:))
        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.widthAnchor.constraint(equalToConstant: 170).isActive = true
        popup.heightAnchor.constraint(equalToConstant: 30).isActive = true
        return popup
    }

    private func metricTabs() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 0
        for (index, metric) in UsageActivityMetric.allCases.enumerated() {
            let title = metric == .requests ? texts.activityRequests : texts.activityTokens
            let button = NSButton(title: title, target: self, action: #selector(metricChanged(_:)))
            button.tag = index
            button.translatesAutoresizingMaskIntoConstraints = false
            button.widthAnchor.constraint(equalToConstant: 92).isActive = true
            button.heightAnchor.constraint(equalToConstant: 30).isActive = true
            RelayTheme.styleButton(button, tint: RelayTheme.up, isSelected: metric == selectedMetric, fontSize: 10)
            row.addArrangedSubview(button)
        }
        return row
    }

    private func displayModeTabs() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 0
        for (index, mode) in UsageActivityDisplayMode.allCases.enumerated() {
            let title = mode == .calendarYear ? texts.activityThisYear : texts.activityLastYear
            let button = NSButton(title: title, target: self, action: #selector(displayModeChanged(_:)))
            button.tag = index
            button.translatesAutoresizingMaskIntoConstraints = false
            button.widthAnchor.constraint(equalToConstant: 92).isActive = true
            button.heightAnchor.constraint(equalToConstant: 30).isActive = true
            RelayTheme.styleButton(button, tint: RelayTheme.cyan, isSelected: mode == selectedDisplayMode, fontSize: 10)
            row.addArrangedSubview(button)
        }
        return row
    }

    private func selectedSnapshot() -> UsageSnapshot {
        if selectedSourceID == UsageDashboardSnapshot.aggregateSourceID {
            return dashboard.aggregate
        }
        return dashboard.adapters.first { $0.sourceID == selectedSourceID } ?? dashboard.aggregate
    }

    private func activitySummary(_ dataset: UsageActivityDataset) -> NSTextField {
        let total = dataset.days.reduce(0) { total, day in
            total + (selectedMetric == .requests ? day.requests : day.tokens)
        }
        let unit = selectedMetric == .requests ? texts.requests : texts.activityTokens
        let prefix: String
        switch dataset.availability {
        case .complete: prefix = ""
        case .partial: prefix = "\(texts.activityPartial) · "
        case .unavailable:
            prefix = dataset.unavailableReason == .dataExportDisabled
                ? "\(texts.activityDataExportDisabled) · "
                : "\(texts.activityUnavailable) · "
        }
        return menuLabel("\(prefix)\(MenuValueFormatter.number(total)) \(unit)", size: 11, weight: .bold, color: dataset.availability == .complete ? RelayTheme.muted : RelayTheme.warn)
    }

    private func detail(_ day: UsageActivityDay?) -> String {
        guard let day else { return "--" }
        let date = DateFormatter.localizedString(from: day.start, dateStyle: .medium, timeStyle: .none)
        if day.state == .unknown { return "\(date) · \(texts.activityUnknown)" }
        let suffix = day.state == .partial ? " · \(texts.activityPartial)" : ""
        return "\(date) · \(MenuValueFormatter.number(day.requests)) \(texts.requests) · \(MenuValueFormatter.compact(day.tokens)) \(texts.activityTokens)\(suffix)"
    }

    @objc private func sourceChanged(_ sender: PixelPopupButton) {
        guard let sourceID = sender.selectedRepresentedObject as? String,
              sourceIDs.contains(sourceID) else { return }
        selectedSourceID = sourceID
        rebuildContent()
    }

    @objc private func metricChanged(_ sender: NSButton) {
        guard UsageActivityMetric.allCases.indices.contains(sender.tag) else { return }
        selectedMetric = UsageActivityMetric.allCases[sender.tag]
        rebuildContent()
    }

    @objc private func displayModeChanged(_ sender: NSButton) {
        guard UsageActivityDisplayMode.allCases.indices.contains(sender.tag) else { return }
        selectedDisplayMode = UsageActivityDisplayMode.allCases[sender.tag]
        rebuildContent()
    }
}
