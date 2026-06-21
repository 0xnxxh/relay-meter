import AppKit

final class SnapshotMenuView: NSView {
    private let contentWidth: CGFloat = 380
    private let onRangeSelected: ((UsageTimeRange) -> Void)?
    private let onSourceSelected: ((String) -> Void)?
    private let onRefresh: (() -> Void)?
    private let onOpenMonitoring: (() -> Void)?
    private var sourceTabs: [(id: String, title: String)] = []

    init(
        snapshot: UsageSnapshot,
        config: AppConfig?,
        texts: TextBundle,
        onRangeSelected: ((UsageTimeRange) -> Void)? = nil,
        onSourceSelected: ((String) -> Void)? = nil,
        onRefresh: (() -> Void)? = nil,
        onOpenMonitoring: (() -> Void)? = nil
    ) {
        self.onRangeSelected = onRangeSelected
        self.onSourceSelected = onSourceSelected
        self.onRefresh = onRefresh
        self.onOpenMonitoring = onOpenMonitoring
        super.init(frame: NSRect(x: 0, y: 0, width: contentWidth, height: 1))
        build(snapshot: snapshot, config: config, texts: texts)
    }

    init(
        dashboard: UsageDashboardSnapshot,
        config: AppConfig?,
        texts: TextBundle,
        selectedSourceID: String = UsageDashboardSnapshot.aggregateSourceID,
        onRangeSelected: ((UsageTimeRange) -> Void)? = nil,
        onSourceSelected: ((String) -> Void)? = nil,
        onRefresh: (() -> Void)? = nil,
        onOpenMonitoring: (() -> Void)? = nil
    ) {
        self.onRangeSelected = onRangeSelected
        self.onSourceSelected = onSourceSelected
        self.onRefresh = onRefresh
        self.onOpenMonitoring = onOpenMonitoring
        super.init(frame: NSRect(x: 0, y: 0, width: contentWidth, height: 1))
        build(dashboard: dashboard, selectedSourceID: selectedSourceID, config: config, texts: texts)
    }

    required init?(coder: NSCoder) {
        nil
    }

    static func loading(
        texts: TextBundle,
        config: AppConfig?,
        selectedRange: UsageTimeRange,
        selectedSourceID: String = UsageDashboardSnapshot.aggregateSourceID,
        onRangeSelected: ((UsageTimeRange) -> Void)? = nil,
        onSourceSelected: ((String) -> Void)? = nil,
        onRefresh: (() -> Void)? = nil,
        onOpenMonitoring: (() -> Void)? = nil
    ) -> SnapshotMenuView {
        let snapshot = UsageSnapshot(
            sourceID: "loading",
            sourceName: config?.primaryAdapter.displayName ?? "Relay Meter",
            platform: config?.resolvedPlatform ?? .cliproxyapiPro,
            selectedRange: selectedRange,
            scope: UsageScope(),
            recent: UsageScope(),
            trendPoints: [],
            topModels: [],
            topApiKeys: [],
            refreshedAt: Date()
        )
        let dashboard = UsageDashboardSnapshot(
            selectedRange: selectedRange,
            aggregate: snapshot,
            adapters: [],
            errors: [],
            refreshedAt: Date()
        )
        return SnapshotMenuView(
            dashboard: dashboard,
            config: config,
            texts: texts,
            selectedSourceID: selectedSourceID,
            onRangeSelected: onRangeSelected,
            onSourceSelected: onSourceSelected,
            onRefresh: onRefresh,
            onOpenMonitoring: onOpenMonitoring
        )
    }

    private func build(dashboard: UsageDashboardSnapshot, selectedSourceID: String, config: AppConfig?, texts: TextBundle) {
        let root = baseStack()
        let enabled = Set(config?.resolvedListItems ?? DisplayItem.defaultItems)
        let selectedSnapshot = snapshot(for: selectedSourceID, dashboard: dashboard)
        root.addArrangedSubview(header(
            snapshot: selectedSnapshot,
            title: title(for: selectedSnapshot, dashboard: dashboard, texts: texts),
            dashboard: dashboard,
            selectedSourceID: selectedSnapshot.sourceID,
            config: config,
            enabled: enabled,
            texts: texts
        ))

        for card in metricCards(snapshot: selectedSnapshot, enabled: enabled, texts: texts) {
            root.addArrangedSubview(card)
        }

        if selectedSnapshot.sourceID == UsageDashboardSnapshot.aggregateSourceID, !dashboard.errors.isEmpty {
            root.addArrangedSubview(adapterErrorsCard(dashboard: dashboard, texts: texts))
        }

        if enabled.contains(.topModel) || enabled.contains(.topApiKey) {
            root.addArrangedSubview(rankingCard(snapshot: selectedSnapshot, enabled: enabled, texts: texts))
        }

        if enabled.contains(.trend) {
            root.addArrangedSubview(trendCard(snapshot: selectedSnapshot, texts: texts))
        }

        finalizeLayout(root: root)
    }

    private func build(snapshot: UsageSnapshot, config: AppConfig?, texts: TextBundle) {
        let root = baseStack()
        let enabled = Set(config?.resolvedListItems ?? DisplayItem.defaultItems)
        root.addArrangedSubview(header(snapshot: snapshot, title: "\(snapshot.sourceName) · \(snapshot.selectedRange.label(texts: texts))", dashboard: nil, selectedSourceID: snapshot.sourceID, config: config, enabled: enabled, texts: texts))

        let cards = metricCards(snapshot: snapshot, enabled: enabled, texts: texts)
        for card in cards {
            root.addArrangedSubview(card)
        }

        if enabled.contains(.topModel) || enabled.contains(.topApiKey) {
            root.addArrangedSubview(rankingCard(snapshot: snapshot, enabled: enabled, texts: texts))
        }

        if enabled.contains(.trend) {
            root.addArrangedSubview(trendCard(snapshot: snapshot, texts: texts))
        }

        finalizeLayout(root: root)
    }

    private func baseStack() -> NSStackView {
        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 7
        root.edgeInsets = NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        root.translatesAutoresizingMaskIntoConstraints = false
        addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: leadingAnchor),
            root.trailingAnchor.constraint(equalTo: trailingAnchor),
            root.topAnchor.constraint(equalTo: topAnchor),
            root.bottomAnchor.constraint(equalTo: bottomAnchor),
            widthAnchor.constraint(equalToConstant: contentWidth)
        ])
        return root
    }

    private func finalizeLayout(root: NSStackView) {
        layoutSubtreeIfNeeded()
        let height = root.fittingSize.height
        setFrameSize(NSSize(width: contentWidth, height: height))
    }

    private func header(snapshot: UsageSnapshot, title: String, dashboard: UsageDashboardSnapshot?, selectedSourceID: String, config: AppConfig?, enabled: Set<DisplayItem>, texts: TextBundle) -> NSView {
        let card = RoundedPanelView(accentColor: menuHealthColor(snapshot.health), fillAlpha: 0.08)
        card.translatesAutoresizingMaskIntoConstraints = false
        card.widthAnchor.constraint(equalToConstant: contentWidth - 24).isActive = true

        let row = NSStackView()
        row.orientation = .vertical
        row.alignment = .leading
        row.spacing = 6
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8)
        ])

        let topRow = NSStackView()
        topRow.orientation = .horizontal
        topRow.alignment = .centerY
        topRow.spacing = 10
        row.addArrangedSubview(topRow)

        let rangeLabel = menuLabel(title, size: 13, weight: .semibold, color: .labelColor)
        topRow.addArrangedSubview(rangeLabel)
        topRow.addArrangedSubview(healthIndicator(snapshot: snapshot, config: config))

        topRow.addArrangedSubview(NSView())

        if enabled.contains(.refreshedAt) {
            let updated = DateFormatter.localizedString(from: snapshot.refreshedAt, dateStyle: .none, timeStyle: .medium)
            let updatedLabel = menuLabel("\(texts.updated) \(updated)", size: 11, weight: .regular, color: .secondaryLabelColor)
            updatedLabel.alignment = .right
            topRow.addArrangedSubview(updatedLabel)
        }
        topRow.addArrangedSubview(actionButton(systemSymbol: "arrow.clockwise", fallbackTitle: "R", tooltip: texts.refresh, action: #selector(refreshTapped)))
        topRow.addArrangedSubview(actionButton(systemSymbol: "safari", fallbackTitle: "M", tooltip: texts.openMonitoring, action: #selector(openMonitoringTapped)))

        row.addArrangedSubview(rangeTabs(selectedRange: snapshot.selectedRange, texts: texts))
        if let dashboard, !dashboard.adapters.isEmpty {
            row.addArrangedSubview(sourceTabs(dashboard: dashboard, selectedSourceID: selectedSourceID, texts: texts))
        }

        return card
    }

    private func snapshot(for sourceID: String, dashboard: UsageDashboardSnapshot) -> UsageSnapshot {
        if sourceID == UsageDashboardSnapshot.aggregateSourceID {
            return dashboard.aggregate
        }
        return dashboard.adapters.first { $0.sourceID == sourceID } ?? dashboard.aggregate
    }

    private func title(for snapshot: UsageSnapshot, dashboard: UsageDashboardSnapshot, texts: TextBundle) -> String {
        let label = dashboard.selectedRange.label(texts: texts)
        if snapshot.sourceID == UsageDashboardSnapshot.aggregateSourceID {
            return "\(texts.allAdapters) · \(dashboard.adapters.count) · \(label)"
        }
        return "\(snapshot.sourceName) · \(label)"
    }

    private func adapterErrorsCard(dashboard: UsageDashboardSnapshot, texts: TextBundle) -> NSView {
        let card = RoundedPanelView(accentColor: .systemTeal, fillAlpha: 0.045)
        card.translatesAutoresizingMaskIntoConstraints = false
        card.widthAnchor.constraint(equalToConstant: contentWidth - 24).isActive = true

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 11),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -11),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8)
        ])

        stack.addArrangedSubview(menuIconTitle(texts.error, accent: .systemTeal))
        for error in dashboard.errors {
            stack.addArrangedSubview(errorLine(error: error, texts: texts))
        }
        return card
    }

    private func errorLine(error: AdapterSnapshotError, texts: TextBundle) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8

        let dot = StatusDotView(color: .systemRed)
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.widthAnchor.constraint(equalToConstant: 9).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 9).isActive = true
        row.addArrangedSubview(dot)

        let message = menuLabel("\(error.adapterName): \(texts.error)", size: 11, weight: .medium, color: .secondaryLabelColor)
        message.toolTip = error.message
        row.addArrangedSubview(message)
        return row
    }

    private func healthIndicator(snapshot: UsageSnapshot, config: AppConfig?) -> NSView {
        let label = snapshot.health.label(language: currentLanguage(config: config))
        let dot = StatusDotView(color: menuHealthColor(snapshot.health))
        dot.toolTip = label
        dot.setAccessibilityLabel(label)
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.widthAnchor.constraint(equalToConstant: 11).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 11).isActive = true
        return dot
    }

    private func rangeTabs(selectedRange: UsageTimeRange, texts: TextBundle) -> NSView {
        let control = NSSegmentedControl(
            labels: UsageTimeRange.allCases.map { $0.label(texts: texts) },
            trackingMode: .selectOne,
            target: self,
            action: #selector(selectRange)
        )
        control.segmentStyle = .texturedRounded
        control.selectedSegment = UsageTimeRange.allCases.firstIndex(of: selectedRange) ?? 0
        control.translatesAutoresizingMaskIntoConstraints = false
        control.widthAnchor.constraint(equalToConstant: contentWidth - 48).isActive = true
        return control
    }

    private func sourceTabs(dashboard: UsageDashboardSnapshot, selectedSourceID: String, texts: TextBundle) -> NSView {
        let sources = sourceTabItems(dashboard: dashboard, texts: texts)
        sourceTabs = sources
        let control = NSSegmentedControl(
            labels: sources.map { $0.title },
            trackingMode: .selectOne,
            target: self,
            action: #selector(selectSource)
        )
        control.segmentStyle = .texturedRounded
        control.selectedSegment = sources.firstIndex { $0.id == selectedSourceID } ?? 0
        control.translatesAutoresizingMaskIntoConstraints = false
        control.widthAnchor.constraint(equalToConstant: contentWidth - 48).isActive = true
        control.toolTip = texts.adapters
        return control
    }

    private func sourceTabItems(dashboard: UsageDashboardSnapshot, texts: TextBundle) -> [(id: String, title: String)] {
        var items = [(UsageDashboardSnapshot.aggregateSourceID, texts.allAdapters)]
        items.append(contentsOf: dashboard.adapters.map { ($0.sourceID, $0.sourceName) })
        return items
    }

    private func actionButton(systemSymbol: String, fallbackTitle: String, tooltip: String, action: Selector) -> NSButton {
        let button = NSButton(title: fallbackTitle, target: self, action: action)
        button.bezelStyle = .texturedRounded
        button.isBordered = true
        button.imagePosition = .imageOnly
        button.toolTip = tooltip
        button.setAccessibilityLabel(tooltip)
        if let image = NSImage(systemSymbolName: systemSymbol, accessibilityDescription: tooltip) {
            button.image = image
        }
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 28).isActive = true
        button.heightAnchor.constraint(equalToConstant: 24).isActive = true
        return button
    }

    private func metricCards(snapshot: UsageSnapshot, enabled: Set<DisplayItem>, texts: TextBundle) -> [NSView] {
        var cards: [NSView] = []

        if enabled.contains(.traffic) || enabled.contains(.successRate) {
            cards.append(metricCard(
                title: texts.traffic,
                value: MenuValueFormatter.compact(snapshot.scope.totalRequests),
                caption: texts.requests,
                accent: .systemBlue,
                footers: [
                    (texts.successRate, MenuValueFormatter.percent(snapshot.scope.successRate)),
                    (texts.failures, MenuValueFormatter.number(snapshot.scope.failureCount))
                ]
            ))
        }

        if enabled.contains(.tokens) || enabled.contains(.cache) {
            cards.append(metricCard(
                title: texts.tokens,
                value: MenuValueFormatter.compact(snapshot.scope.totalTokens),
                caption: texts.total,
                accent: .systemPurple,
                footers: [
                    ("\(texts.input)/\(texts.output)", "\(MenuValueFormatter.compact(snapshot.scope.inputTokens)) / \(MenuValueFormatter.compact(snapshot.scope.outputTokens))"),
                    (texts.cache, "\(MenuValueFormatter.compact(snapshot.scope.cacheTokens)) / \(MenuValueFormatter.percent(snapshot.scope.cacheRate))")
                ]
            ))
        }

        if enabled.contains(.recent) {
            cards.append(metricCard(
                title: texts.recent,
                value: MenuValueFormatter.compact(snapshot.recent.totalRequests),
                caption: texts.requests,
                accent: .systemGreen,
                footers: [
                    (texts.tokens, MenuValueFormatter.compact(snapshot.recent.totalTokens)),
                    (texts.failures, MenuValueFormatter.number(snapshot.recent.failureCount))
                ]
            ))
        }

        if enabled.contains(.latency) {
            cards.append(metricCard(
                title: texts.latency,
                value: snapshot.scope.avgLatencyMs.map(MenuValueFormatter.duration) ?? "--",
                caption: texts.avg,
                accent: .systemOrange,
                footers: [
                    (texts.ttft, snapshot.scope.avgTtftMs.map(MenuValueFormatter.duration) ?? "--"),
                    (texts.successRate, MenuValueFormatter.percent(snapshot.scope.successRate))
                ]
            ))
        }

        return cards
    }

    private func metricCard(
        title: String,
        value: String,
        caption: String,
        accent: NSColor,
        footers: [(String, String)]
    ) -> NSView {
        let card = RoundedPanelView(accentColor: accent, fillAlpha: 0.055)
        card.translatesAutoresizingMaskIntoConstraints = false
        card.widthAnchor.constraint(equalToConstant: contentWidth - 24).isActive = true

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 11),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -11),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8)
        ])

        let primary = NSStackView()
        primary.orientation = .vertical
        primary.alignment = .leading
        primary.spacing = 3
        primary.addArrangedSubview(menuIconTitle(title, accent: accent))
        let valueLabel = menuLabel(value, size: 22, weight: .bold, color: .labelColor)
        valueLabel.lineBreakMode = .byTruncatingTail
        primary.addArrangedSubview(valueLabel)
        primary.addArrangedSubview(menuLabel(caption, size: 10, weight: .regular, color: .secondaryLabelColor))
        stack.addArrangedSubview(primary)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stack.addArrangedSubview(spacer)

        let footerStack = NSStackView()
        footerStack.orientation = .vertical
        footerStack.alignment = .leading
        footerStack.spacing = 4
        footerStack.widthAnchor.constraint(greaterThanOrEqualToConstant: 132).isActive = true
        for footer in footers {
            footerStack.addArrangedSubview(footerLine(title: footer.0, value: footer.1))
        }
        stack.addArrangedSubview(footerStack)
        return card
    }

    private func rankingCard(snapshot: UsageSnapshot, enabled: Set<DisplayItem>, texts: TextBundle) -> NSView {
        let card = RankingMenuCardView(snapshot: snapshot, enabled: enabled, texts: texts)
        card.translatesAutoresizingMaskIntoConstraints = false
        card.widthAnchor.constraint(equalToConstant: contentWidth - 24).isActive = true
        return card
    }

    private func trendCard(snapshot: UsageSnapshot, texts: TextBundle) -> NSView {
        let card = TrendMenuCardView(points: snapshot.trendPoints, texts: texts)
        card.translatesAutoresizingMaskIntoConstraints = false
        card.widthAnchor.constraint(equalToConstant: contentWidth - 24).isActive = true
        return card
    }

    private func footerLine(title: String, value: String) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .firstBaseline
        row.spacing = 6

        let titleLabel = menuLabel(title, size: 10, weight: .regular, color: .secondaryLabelColor)
        titleLabel.widthAnchor.constraint(equalToConstant: 62).isActive = true
        row.addArrangedSubview(titleLabel)

        let valueLabel = menuLabel(value, size: 11, weight: .semibold, color: .labelColor)
        valueLabel.alignment = .right
        valueLabel.lineBreakMode = .byTruncatingTail
        row.addArrangedSubview(valueLabel)
        return row
    }

    private func currentLanguage(config: AppConfig?) -> AppLanguage {
        config?.resolvedLanguage ?? .english
    }

    @objc private func selectRange(_ sender: NSSegmentedControl) {
        let ranges = UsageTimeRange.allCases
        guard sender.selectedSegment >= 0, sender.selectedSegment < ranges.count else { return }
        onRangeSelected?(ranges[sender.selectedSegment])
    }

    @objc private func selectSource(_ sender: NSSegmentedControl) {
        guard sender.selectedSegment >= 0, sender.selectedSegment < sourceTabs.count else { return }
        onSourceSelected?(sourceTabs[sender.selectedSegment].id)
    }

    @objc private func refreshTapped() {
        onRefresh?()
    }

    @objc private func openMonitoringTapped() {
        onOpenMonitoring?()
    }
}
