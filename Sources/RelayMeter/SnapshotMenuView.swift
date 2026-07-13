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
        RelayTheme.applyWindowBackground(to: self)
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
        RelayTheme.applyWindowBackground(to: self)
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
        root.spacing = 10
        root.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 10, right: 12)
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
        root.needsLayout = true
        root.layoutSubtreeIfNeeded()
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

        let rangeLabel = menuLabel(title.uppercased(), size: 13, weight: .black, color: RelayTheme.text)
        topRow.addArrangedSubview(rangeLabel)
        topRow.addArrangedSubview(healthIndicator(snapshot: snapshot, config: config))

        topRow.addArrangedSubview(NSView())

        if enabled.contains(.refreshedAt) {
            let updated = DateFormatter.localizedString(from: snapshot.refreshedAt, dateStyle: .none, timeStyle: .medium)
            let updatedLabel = menuLabel("\(texts.updated) \(updated)".uppercased(), size: 10, weight: .bold, color: RelayTheme.muted)
            updatedLabel.alignment = .right
            topRow.addArrangedSubview(updatedLabel)
        }
        topRow.addArrangedSubview(actionButton(systemSymbol: "arrow.clockwise", tooltip: texts.refresh, action: #selector(refreshTapped)))
        topRow.addArrangedSubview(actionButton(systemSymbol: "safari", tooltip: texts.openMonitoring, action: #selector(openMonitoringTapped)))

        row.addArrangedSubview(rangeTabs(selectedRange: snapshot.selectedRange, texts: texts))
        // Single-adapter setups show identical aggregate vs adapter content; hide redundant source tabs.
        if let dashboard, dashboard.adapters.count > 1 {
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
        let card = RoundedPanelView(accentColor: RelayTheme.line, fillAlpha: 0.92)
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

        stack.addArrangedSubview(menuIconTitle(texts.error, accent: RelayTheme.down, icon: .error))
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

        let dot = StatusDotView(color: RelayTheme.down)
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.widthAnchor.constraint(equalToConstant: 9).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 9).isActive = true
        row.addArrangedSubview(dot)

        let message = menuLabel("\(error.adapterName): \(texts.error)", size: 11, weight: .bold, color: RelayTheme.muted)
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
        let selectedIndex = UsageTimeRange.allCases.firstIndex(of: selectedRange) ?? 0
        return pixelTabs(
            titles: UsageTimeRange.allCases.map { $0.label(texts: texts) },
            selectedIndex: selectedIndex,
            target: self,
            action: #selector(selectRangeButton)
        )
    }

    private func sourceTabs(dashboard: UsageDashboardSnapshot, selectedSourceID: String, texts: TextBundle) -> NSView {
        let sources = sourceTabItems(dashboard: dashboard, texts: texts)
        sourceTabs = sources
        let selectedIndex = sources.firstIndex { $0.id == selectedSourceID } ?? 0
        let control = pixelTabs(
            titles: sources.map { $0.title },
            selectedIndex: selectedIndex,
            target: self,
            action: #selector(selectSourceButton)
        )
        control.toolTip = texts.adapters
        return control
    }

    private func sourceTabItems(dashboard: UsageDashboardSnapshot, texts: TextBundle) -> [(id: String, title: String)] {
        var items = [(UsageDashboardSnapshot.aggregateSourceID, texts.allAdapters)]
        items.append(contentsOf: dashboard.adapters.map { ($0.sourceID, $0.sourceName) })
        return items
    }

    private func actionButton(systemSymbol: String, tooltip: String, action: Selector) -> NSButton {
        let button = NSButton(title: "", target: self, action: action)
        button.imagePosition = .imageOnly
        button.toolTip = tooltip
        button.setAccessibilityLabel(tooltip)
        if let image = NSImage(systemSymbolName: systemSymbol, accessibilityDescription: tooltip) {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .bold)
            button.image = image.withSymbolConfiguration(config)
            button.image?.isTemplate = true
        }
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 28).isActive = true
        button.heightAnchor.constraint(equalToConstant: 24).isActive = true
        RelayTheme.styleButton(button, tint: RelayTheme.accent)
        // Keep pure icon: styleButton may re-apply an empty attributed title; ensure no glyph text shows.
        button.title = ""
        button.attributedTitle = NSAttributedString(string: "")
        return button
    }

    private func pixelTabs(titles: [String], selectedIndex: Int, target: AnyObject, action: Selector) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fillEqually
        row.spacing = 0
        row.translatesAutoresizingMaskIntoConstraints = false
        row.widthAnchor.constraint(equalToConstant: contentWidth - 48).isActive = true
        row.heightAnchor.constraint(equalToConstant: 36).isActive = true

        for (index, title) in titles.enumerated() {
            let button = NSButton(title: title, target: target, action: action)
            button.tag = index
            button.setButtonType(.momentaryPushIn)
            RelayTheme.styleButton(button, tint: index == selectedIndex ? RelayTheme.accent : RelayTheme.cyan, isSelected: index == selectedIndex, fontSize: 12)
            row.addArrangedSubview(button)
        }
        return row
    }

    private func metricCards(snapshot: UsageSnapshot, enabled: Set<DisplayItem>, texts: TextBundle) -> [NSView] {
        var cards: [NSView] = []

        if enabled.contains(.traffic) || enabled.contains(.successRate) {
            cards.append(metricCard(
                title: texts.traffic,
                value: MenuValueFormatter.compact(snapshot.scope.totalRequests),
                caption: texts.requests,
                accent: RelayTheme.cyan,
                icon: .traffic,
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
                accent: RelayTheme.accent,
                icon: .tokens,
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
                accent: RelayTheme.up,
                icon: .recent,
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
                accent: RelayTheme.warn,
                icon: .latency,
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
        icon: MenuPixelIconKind,
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
        primary.addArrangedSubview(menuIconTitle(title, accent: accent, icon: icon))
        let valueLabel = menuLabel(value, size: 24, weight: .black, color: RelayTheme.text)
        valueLabel.lineBreakMode = .byTruncatingTail
        primary.addArrangedSubview(valueLabel)
        primary.addArrangedSubview(menuLabel(caption.uppercased(), size: 10, weight: .bold, color: RelayTheme.muted))
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

        let titleLabel = menuLabel(title.uppercased(), size: 10, weight: .bold, color: RelayTheme.muted)
        titleLabel.widthAnchor.constraint(equalToConstant: 62).isActive = true
        row.addArrangedSubview(titleLabel)

        let valueLabel = menuLabel(value, size: 11, weight: .bold, color: RelayTheme.text)
        valueLabel.alignment = .right
        valueLabel.lineBreakMode = .byTruncatingTail
        row.addArrangedSubview(valueLabel)
        return row
    }

    private func currentLanguage(config: AppConfig?) -> AppLanguage {
        config?.resolvedLanguage ?? .english
    }

    @objc private func selectRangeButton(_ sender: NSButton) {
        let ranges = UsageTimeRange.allCases
        guard ranges.indices.contains(sender.tag) else { return }
        onRangeSelected?(ranges[sender.tag])
    }

    @objc private func selectSourceButton(_ sender: NSButton) {
        guard sourceTabs.indices.contains(sender.tag) else { return }
        onSourceSelected?(sourceTabs[sender.tag].id)
    }

    @objc private func refreshTapped() {
        onRefresh?()
    }

    @objc private func openMonitoringTapped() {
        onOpenMonitoring?()
    }
}

final class MenuFooterView: NSView {
    private let contentWidth: CGFloat = 380
    private let onSettings: () -> Void
    private let onQuit: () -> Void

    init(texts: TextBundle, onSettings: @escaping () -> Void, onQuit: @escaping () -> Void) {
        self.onSettings = onSettings
        self.onQuit = onQuit
        super.init(frame: NSRect(x: 0, y: 0, width: contentWidth, height: 54))
        RelayTheme.applyWindowBackground(to: self)
        build(texts: texts)
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func build(texts: TextBundle) {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 10, right: 12)
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        let settingsButton = NSButton(title: texts.settings, target: self, action: #selector(settingsTapped))
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.heightAnchor.constraint(equalToConstant: 30).isActive = true
        settingsButton.widthAnchor.constraint(equalToConstant: 78).isActive = true
        RelayTheme.styleButton(settingsButton, tint: RelayTheme.cyan, fontSize: 12)

        let quitButton = NSButton(title: texts.quit, target: self, action: #selector(quitTapped))
        quitButton.translatesAutoresizingMaskIntoConstraints = false
        quitButton.heightAnchor.constraint(equalToConstant: 30).isActive = true
        quitButton.widthAnchor.constraint(equalToConstant: 66).isActive = true
        RelayTheme.styleButton(quitButton, tint: RelayTheme.down, fontSize: 12)

        row.addArrangedSubview(NSView())
        row.addArrangedSubview(settingsButton)
        row.addArrangedSubview(quitButton)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
            widthAnchor.constraint(equalToConstant: contentWidth),
            heightAnchor.constraint(equalToConstant: 54)
        ])
    }

    @objc private func settingsTapped() {
        onSettings()
    }

    @objc private func quitTapped() {
        onQuit()
    }
}
