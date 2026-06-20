import AppKit

final class SnapshotMenuView: NSView {
    private let contentWidth: CGFloat = 380
    private let onRangeSelected: ((UsageTimeRange) -> Void)?
    private let onRefresh: (() -> Void)?
    private let onOpenMonitoring: (() -> Void)?

    init(
        snapshot: UsageSnapshot,
        config: AppConfig?,
        texts: TextBundle,
        onRangeSelected: ((UsageTimeRange) -> Void)? = nil,
        onRefresh: (() -> Void)? = nil,
        onOpenMonitoring: (() -> Void)? = nil
    ) {
        self.onRangeSelected = onRangeSelected
        self.onRefresh = onRefresh
        self.onOpenMonitoring = onOpenMonitoring
        super.init(frame: NSRect(x: 0, y: 0, width: contentWidth, height: 1))
        build(snapshot: snapshot, config: config, texts: texts)
    }

    required init?(coder: NSCoder) {
        nil
    }

    static func loading(
        texts: TextBundle,
        config: AppConfig?,
        selectedRange: UsageTimeRange,
        onRangeSelected: ((UsageTimeRange) -> Void)? = nil,
        onRefresh: (() -> Void)? = nil,
        onOpenMonitoring: (() -> Void)? = nil
    ) -> SnapshotMenuView {
        let snapshot = UsageSnapshot(
            selectedRange: selectedRange,
            scope: UsageScope(),
            recent: UsageScope(),
            trendPoints: [],
            topModels: [],
            topApiKeys: [],
            refreshedAt: Date()
        )
        return SnapshotMenuView(
            snapshot: snapshot,
            config: config,
            texts: texts,
            onRangeSelected: onRangeSelected,
            onRefresh: onRefresh,
            onOpenMonitoring: onOpenMonitoring
        )
    }

    private func build(snapshot: UsageSnapshot, config: AppConfig?, texts: TextBundle) {
        let enabled = Set(config?.resolvedListItems ?? DisplayItem.defaultItems)
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

        root.addArrangedSubview(header(snapshot: snapshot, config: config, enabled: enabled, texts: texts))

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

        layoutSubtreeIfNeeded()
        let height = root.fittingSize.height
        setFrameSize(NSSize(width: contentWidth, height: height))
    }

    private func header(snapshot: UsageSnapshot, config: AppConfig?, enabled: Set<DisplayItem>, texts: TextBundle) -> NSView {
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

        let rangeLabel = menuLabel(snapshot.selectedRange.label(texts: texts), size: 13, weight: .semibold, color: .labelColor)
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

        return card
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

    @objc private func refreshTapped() {
        onRefresh?()
    }

    @objc private func openMonitoringTapped() {
        onOpenMonitoring?()
    }
}
