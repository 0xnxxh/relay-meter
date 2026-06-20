import AppKit

final class SettingsWindowController: NSWindowController {
    private enum Layout {
        static let windowSize = NSSize(width: 560, height: 620)
        static let contentWidth: CGFloat = 496
        static let windowWidth: CGFloat = 560
        static let labelWidth: CGFloat = 150
        static let controlWidth: CGFloat = 300
        static let managementKeyFieldWidth: CGFloat = 228
        static let verticalChromePadding: CGFloat = 32
    }

    private var config: AppConfig
    private let onSave: (AppConfig) -> Void
    private let baseURLField = NSTextField()
    private let managementKeyField = NSSecureTextField()
    private let managementKeyVisibleField = NSTextField()
    private let managementKeyToggle = NSButton()
    private let refreshIntervalField = NSTextField()
    private let languagePopup = NSPopUpButton()
    private let titlePopup = NSPopUpButton()
    private let rangePopup = NSPopUpButton()
    private var itemButtons: [DisplayItem: NSButton] = [:]
    private var isManagementKeyVisible = false

    private var texts: TextBundle {
        TextBundle.forLanguage(config.resolvedLanguage)
    }

    init(config: AppConfig, onSave: @escaping (AppConfig) -> Void) {
        self.config = config
        self.onSave = onSave
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Layout.windowSize),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = config.resolvedLanguage == .chinese ? "CPA 菜单栏设置" : "CPA Menubar Settings"
        window.minSize = NSSize(width: Layout.windowWidth, height: 360)
        super.init(window: window)
        window.center()
        window.contentView = buildContentView()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func buildContentView() -> NSView {
        configureControls()

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 0
        root.translatesAutoresizingMaskIntoConstraints = false

        let header = buildHeader()
        let scrollView = buildScrollView()
        let footer = buildFooter()

        root.addArrangedSubview(header)
        root.addArrangedSubview(scrollView)
        root.addArrangedSubview(footer)

        let container = NSView()
        container.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            root.topAnchor.constraint(equalTo: container.topAnchor),
            root.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            header.widthAnchor.constraint(equalTo: root.widthAnchor),
            scrollView.widthAnchor.constraint(equalTo: root.widthAnchor),
            footer.widthAnchor.constraint(equalTo: root.widthAnchor)
        ])
        updateWindowSizeLimits(header: header, scrollView: scrollView, footer: footer)
        return container
    }

    private func configureControls() {
        configureField(baseURLField, value: config.baseURL)
        configureField(managementKeyField, value: config.managementKey, constrainWidth: false)
        configureField(refreshIntervalField, value: "\(Int(config.refreshInterval))")
        refreshIntervalField.alignment = .right

        configurePopup(
            languagePopup,
            items: AppLanguage.allCases.map { ($0.rawValue, languageLabel($0)) },
            selected: config.resolvedLanguage.rawValue
        )
        configurePopup(
            titlePopup,
            items: DisplayMetric.allCases.map { ($0.rawValue, metricLabel($0)) },
            selected: config.resolvedTitleMetric.rawValue
        )
        configurePopup(
            rangePopup,
            items: UsageTimeRange.allCases.map { ($0.rawValue, $0.label(texts: texts)) },
            selected: config.resolvedTimeRange.rawValue
        )
    }

    private func buildHeader() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.edgeInsets = NSEdgeInsets(top: 22, left: 28, bottom: 16, right: 28)

        let title = label(config.resolvedLanguage == .chinese ? "设置" : "Settings", size: 20, weight: .semibold)
        let subtitle = label(
            config.resolvedLanguage == .chinese ? "配置连接、菜单栏显示和监控卡片。" : "Configure connection, menu bar display, and monitoring cards.",
            size: 12,
            weight: .regular,
            color: .secondaryLabelColor
        )
        stack.addArrangedSubview(title)
        stack.addArrangedSubview(subtitle)
        return stack
    }

    private func buildScrollView() -> NSScrollView {
        let content = NSStackView()
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 14
        content.edgeInsets = NSEdgeInsets(top: 14, left: 28, bottom: 18, right: 28)
        content.translatesAutoresizingMaskIntoConstraints = false

        content.addArrangedSubview(section(
            title: config.resolvedLanguage == .chinese ? "连接" : "Connection",
            rows: [
                formRow(title: texts.baseURL, control: baseURLField),
                formRow(title: texts.managementKey, control: managementKeyControl()),
                formRow(title: texts.refreshIntervalSeconds, control: refreshIntervalField)
            ]
        ))

        content.addArrangedSubview(section(
            title: config.resolvedLanguage == .chinese ? "显示" : "Display",
            rows: [
                formRow(title: config.resolvedLanguage == .chinese ? "语言" : "Language", control: languagePopup),
                formRow(title: config.resolvedLanguage == .chinese ? "菜单栏默认显示" : "Menu Bar Title", control: titlePopup),
                formRow(title: texts.range, control: rangePopup)
            ]
        ))

        content.addArrangedSubview(section(
            title: config.resolvedLanguage == .chinese ? "卡片" : "Cards",
            rows: [cardOptionsView(), hintLabel()]
        ))

        let documentWidth = Layout.windowWidth
        let document = SettingsDocumentView(frame: NSRect(x: 0, y: 0, width: documentWidth, height: 1))
        document.addSubview(content)
        NSLayoutConstraint.activate([
            content.centerXAnchor.constraint(equalTo: document.centerXAnchor),
            content.topAnchor.constraint(equalTo: document.topAnchor),
            content.bottomAnchor.constraint(equalTo: document.bottomAnchor),
            content.widthAnchor.constraint(equalToConstant: Layout.contentWidth)
        ])
        content.layoutSubtreeIfNeeded()
        let fittingHeight = max(ceil(content.fittingSize.height), 1)
        document.setFrameSize(NSSize(width: documentWidth, height: fittingHeight))

        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.setContentHuggingPriority(.defaultLow, for: .vertical)
        scrollView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        scrollView.documentView = document
        scrollView.contentView.scroll(to: .zero)
        scrollView.reflectScrolledClipView(scrollView.contentView)
        return scrollView
    }

    private func updateWindowSizeLimits(header: NSView, scrollView: NSScrollView, footer: NSView) {
        guard let window else { return }
        let documentHeight = scrollView.documentView?.frame.height ?? 0
        let maxContentHeight = header.fittingSize.height + documentHeight + footer.fittingSize.height
        let maxHeight = maxContentHeight + Layout.verticalChromePadding
        window.maxSize = NSSize(width: Layout.windowWidth, height: maxHeight)
        window.setContentSize(NSSize(width: Layout.windowSize.width, height: maxContentHeight))
    }

    private func buildFooter() -> NSView {
        let footer = NSVisualEffectView()
        footer.material = .headerView
        footer.blendingMode = .withinWindow

        let actions = NSStackView()
        actions.orientation = .horizontal
        actions.alignment = .centerY
        actions.spacing = 10
        actions.translatesAutoresizingMaskIntoConstraints = false

        let cancelButton = NSButton(title: config.resolvedLanguage == .chinese ? "取消" : "Cancel", target: self, action: #selector(cancel))
        let saveButton = NSButton(title: config.resolvedLanguage == .chinese ? "保存" : "Save", target: self, action: #selector(save))
        saveButton.keyEquivalent = "\r"

        actions.addArrangedSubview(NSView())
        actions.addArrangedSubview(cancelButton)
        actions.addArrangedSubview(saveButton)
        footer.addSubview(actions)

        NSLayoutConstraint.activate([
            footer.heightAnchor.constraint(equalToConstant: 64),
            actions.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 28),
            actions.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -28),
            actions.centerYAnchor.constraint(equalTo: footer.centerYAnchor)
        ])
        return footer
    }

    private func section(title: String, rows: [NSView]) -> NSView {
        let panel = SettingsSectionPanelView()
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.widthAnchor.constraint(equalToConstant: Layout.contentWidth).isActive = true

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(stack)

        stack.addArrangedSubview(label(title, size: 13, weight: .semibold))
        for row in rows {
            stack.addArrangedSubview(row)
        }
        panel.contentStack = stack

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            stack.topAnchor.constraint(equalTo: panel.topAnchor),
            stack.bottomAnchor.constraint(equalTo: panel.bottomAnchor)
        ])
        return panel
    }

    private func formRow(title: String, control: NSView) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12

        let titleLabel = label(title, size: 12, weight: .medium, color: .secondaryLabelColor)
        titleLabel.widthAnchor.constraint(equalToConstant: Layout.labelWidth).isActive = true
        row.addArrangedSubview(titleLabel)
        row.addArrangedSubview(control)
        return row
    }

    private func cardOptionsView() -> NSView {
        let grid = NSGridView()
        grid.rowSpacing = 8
        grid.columnSpacing = 12
        let enabledItems = Set(config.resolvedListItems)
        let items = DisplayItem.allCases

        for pair in stride(from: 0, to: items.count, by: 2) {
            let left = checkbox(for: items[pair], enabledItems: enabledItems)
            let right = pair + 1 < items.count ? checkbox(for: items[pair + 1], enabledItems: enabledItems) : NSView()
            grid.addRow(with: [left, right])
        }
        grid.column(at: 0).width = 214
        grid.column(at: 1).width = 214
        return grid
    }

    private func managementKeyControl() -> NSView {
        configureField(managementKeyVisibleField, value: managementKeyField.stringValue, constrainWidth: false)
        managementKeyVisibleField.isHidden = true

        managementKeyToggle.title = config.resolvedLanguage == .chinese ? "显示" : "Show"
        managementKeyToggle.bezelStyle = .rounded
        managementKeyToggle.target = self
        managementKeyToggle.action = #selector(toggleManagementKeyVisibility)
        managementKeyToggle.translatesAutoresizingMaskIntoConstraints = false
        managementKeyToggle.widthAnchor.constraint(equalToConstant: 64).isActive = true

        let fieldContainer = NSView()
        fieldContainer.translatesAutoresizingMaskIntoConstraints = false
        fieldContainer.addSubview(managementKeyField)
        fieldContainer.addSubview(managementKeyVisibleField)
        NSLayoutConstraint.activate([
            fieldContainer.widthAnchor.constraint(equalToConstant: Layout.managementKeyFieldWidth),
            fieldContainer.heightAnchor.constraint(equalTo: managementKeyField.heightAnchor),
            managementKeyField.leadingAnchor.constraint(equalTo: fieldContainer.leadingAnchor),
            managementKeyField.trailingAnchor.constraint(equalTo: fieldContainer.trailingAnchor),
            managementKeyField.centerYAnchor.constraint(equalTo: fieldContainer.centerYAnchor),
            managementKeyVisibleField.leadingAnchor.constraint(equalTo: fieldContainer.leadingAnchor),
            managementKeyVisibleField.trailingAnchor.constraint(equalTo: fieldContainer.trailingAnchor),
            managementKeyVisibleField.centerYAnchor.constraint(equalTo: fieldContainer.centerYAnchor)
        ])

        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.addArrangedSubview(fieldContainer)
        row.addArrangedSubview(managementKeyToggle)
        return row
    }

    private func checkbox(for item: DisplayItem, enabledItems: Set<DisplayItem>) -> NSButton {
        let button = NSButton(checkboxWithTitle: itemLabel(item), target: nil, action: nil)
        button.state = enabledItems.contains(item) ? .on : .off
        button.font = .systemFont(ofSize: 12)
        button.lineBreakMode = .byTruncatingTail
        itemButtons[item] = button
        return button
    }

    private func hintLabel() -> NSTextField {
        let text = config.resolvedLanguage == .chinese
            ? "卡片数据来自 CLIProxyAPI-Pro /usage/aggregates 字段与分组：provider、model、endpoint、api_key_hash。"
            : "Cards are backed by CLIProxyAPI-Pro /usage/aggregates fields and groups: provider, model, endpoint, api_key_hash."
        let hint = label(text, size: 11, weight: .regular, color: .tertiaryLabelColor)
        hint.maximumNumberOfLines = 2
        hint.lineBreakMode = .byTruncatingTail
        hint.widthAnchor.constraint(equalToConstant: Layout.contentWidth - 32).isActive = true
        return hint
    }

    private func configurePopup(_ popup: NSPopUpButton, items: [(String, String)], selected: String) {
        popup.removeAllItems()
        for item in items {
            popup.addItem(withTitle: item.1)
            popup.lastItem?.representedObject = item.0
        }
        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.widthAnchor.constraint(equalToConstant: Layout.controlWidth).isActive = true
        if let menuItem = popup.itemArray.first(where: { ($0.representedObject as? String) == selected }) {
            popup.select(menuItem)
        }
    }

    private func configureField(_ field: NSTextField, value: String, constrainWidth: Bool = true) {
        field.stringValue = value
        field.translatesAutoresizingMaskIntoConstraints = false
        if constrainWidth {
            field.widthAnchor.constraint(equalToConstant: Layout.controlWidth).isActive = true
        }
    }

    private func label(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor = .labelColor) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: size, weight: weight)
        field.textColor = color
        field.lineBreakMode = .byTruncatingTail
        return field
    }

    private func languageLabel(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "English"
        case .chinese: return "简体中文"
        }
    }

    private func metricLabel(_ metric: DisplayMetric) -> String {
        switch metric {
        case .requests: return config.resolvedLanguage == .chinese ? "请求数 + 成功率" : "Requests + success rate"
        case .tokens: return config.resolvedLanguage == .chinese ? "总 Token" : "Total tokens"
        case .failures: return config.resolvedLanguage == .chinese ? "失败数" : "Failures"
        case .successRate: return config.resolvedLanguage == .chinese ? "成功率" : "Success rate"
        case .latency: return config.resolvedLanguage == .chinese ? "平均延迟" : "Average latency"
        case .cache: return config.resolvedLanguage == .chinese ? "缓存 Token" : "Cache tokens"
        case .recent: return config.resolvedLanguage == .chinese ? "最近 15 分钟活跃" : "Last 15m activity"
        }
    }

    private func itemLabel(_ item: DisplayItem) -> String {
        switch item {
        case .traffic: return config.resolvedLanguage == .chinese ? "流量" : "Traffic"
        case .successRate: return config.resolvedLanguage == .chinese ? "成功率" : "Success rate"
        case .tokens: return config.resolvedLanguage == .chinese ? "Token" : "Tokens"
        case .cache: return config.resolvedLanguage == .chinese ? "缓存" : "Cache"
        case .latency: return config.resolvedLanguage == .chinese ? "延迟" : "Latency"
        case .recent: return config.resolvedLanguage == .chinese ? "最近 15 分钟" : "Last 15m"
        case .trend: return config.resolvedLanguage == .chinese ? "趋势曲线图" : "Trend chart"
        case .topModel: return config.resolvedLanguage == .chinese ? "Top 模型" : "Top model"
        case .topApiKey: return config.resolvedLanguage == .chinese ? "Top API Key" : "Top API key"
        case .refreshedAt: return config.resolvedLanguage == .chinese ? "最后更新时间" : "Last updated"
        }
    }

    @objc private func save() {
        config.baseURL = baseURLField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        config.managementKey = currentManagementKey()
        if let interval = TimeInterval(refreshIntervalField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) {
            config.refreshIntervalSeconds = interval
        }
        config.language = AppLanguage(rawValue: selectedValue(languagePopup))
        config.titleMetric = DisplayMetric(rawValue: selectedValue(titlePopup))
        config.timeRange = UsageTimeRange(rawValue: selectedValue(rangePopup))
        config.display = config.titleMetric?.rawValue
        config.listItems = DisplayItem.allCases.filter { itemButtons[$0]?.state == .on }
        onSave(config)
        close()
    }

    @objc private func cancel() {
        close()
    }

    private func selectedValue(_ popup: NSPopUpButton) -> String {
        popup.selectedItem?.representedObject as? String ?? ""
    }

    private func currentManagementKey() -> String {
        isManagementKeyVisible ? managementKeyVisibleField.stringValue : managementKeyField.stringValue
    }

    @objc private func toggleManagementKeyVisibility() {
        isManagementKeyVisible.toggle()
        if isManagementKeyVisible {
            managementKeyVisibleField.stringValue = managementKeyField.stringValue
        } else {
            managementKeyField.stringValue = managementKeyVisibleField.stringValue
        }
        managementKeyField.isHidden = isManagementKeyVisible
        managementKeyVisibleField.isHidden = !isManagementKeyVisible
        managementKeyToggle.title = isManagementKeyVisible
            ? (config.resolvedLanguage == .chinese ? "隐藏" : "Hide")
            : (config.resolvedLanguage == .chinese ? "显示" : "Show")
    }
}

private final class SettingsSectionPanelView: NSView {
    weak var contentStack: NSStackView?

    override var intrinsicContentSize: NSSize {
        let height = contentStack?.fittingSize.height ?? NSView.noIntrinsicMetric
        return NSSize(width: NSView.noIntrinsicMetric, height: height)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.55).cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.35).cgColor
    }

    required init?(coder: NSCoder) {
        nil
    }
}

private final class SettingsDocumentView: NSView {
    override var isFlipped: Bool {
        true
    }
}
