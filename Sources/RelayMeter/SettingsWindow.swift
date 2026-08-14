import AppKit

final class SettingsWindowController: NSWindowController {
    private enum Layout {
        static let windowSize = NSSize(width: 560, height: 620)
        static let contentWidth: CGFloat = 496
        static let windowWidth: CGFloat = 560
        static let labelWidth: CGFloat = 150
        static let controlWidth: CGFloat = 300
        static let adapterKeyFieldWidth: CGFloat = 228
        static let adapterFieldWidth: CGFloat = 300
        static let adapterTextFieldHeight: CGFloat = 32
        static let adapterHeaderHeight: CGFloat = 44
        static let adapterLabelWidth: CGFloat = 112
    }

    private var config: AppConfig
    private let onSave: (AppConfig) -> Void
    private let onCheckForUpdates: () -> Void
    private var adapterControls: [AdapterConfigControls] = []
    private let adaptersStack = NSStackView()
    private let refreshIntervalField = PixelTextField()
    private let languagePopup = PixelPopupButton()
    private let titlePopup = PixelPopupButton()
    private let rangePopup = PixelPopupButton()
    private var itemButtons: [DisplayItem: NSButton] = [:]
    private weak var headerView: NSView?
    private weak var footerView: NSView?
    private weak var scrollView: NSScrollView?
    private weak var scrollContentStack: NSStackView?
    private weak var settingsDocument: SettingsDocumentView?

    private var texts: TextBundle {
        TextBundle.forLanguage(config.resolvedLanguage)
    }

    private var settingsTexts: SettingsTextBundle {
        SettingsTextBundle.forLanguage(config.resolvedLanguage)
    }

    init(
        config: AppConfig,
        onSave: @escaping (AppConfig) -> Void,
        onCheckForUpdates: @escaping () -> Void
    ) {
        self.config = config
        self.onSave = onSave
        self.onCheckForUpdates = onCheckForUpdates
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Layout.windowSize),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = SettingsTextBundle.forLanguage(config.resolvedLanguage).windowTitle
        window.minSize = NSSize(width: Layout.windowWidth, height: 420)
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.backgroundColor = RelayTheme.background
        window.isOpaque = false
        super.init(window: window)
        window.center()
        window.contentView = buildContentView()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func buildContentView() -> NSView {
        configureControlsIfNeeded()

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 0
        root.translatesAutoresizingMaskIntoConstraints = false

        let header = buildHeader()
        let scrollView = buildScrollView()
        let footer = buildFooter()
        headerView = header
        self.scrollView = scrollView
        footerView = footer

        root.addArrangedSubview(header)
        root.addArrangedSubview(scrollView)
        root.addArrangedSubview(footer)

        let container = RelayBackgroundView()
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
        updateWindowSize(allowGrowth: false)
        return container
    }

    private func configureControls() {
        adapterControls = []
        for adapter in config.adapters {
            adapterControls.append(makeAdapterControls(adapter: adapter))
        }
        adaptersStack.orientation = .vertical
        adaptersStack.alignment = .leading
        adaptersStack.spacing = 14
        configureField(refreshIntervalField, value: "\(Int(config.refreshInterval))")
        refreshIntervalField.alignment = .right

        configurePopup(
            languagePopup,
            items: AppLanguage.allCases.map { ($0.rawValue, settingsTexts.languageLabel($0)) },
            selected: config.resolvedLanguage.rawValue
        )
        configurePopup(
            titlePopup,
            items: DisplayMetric.allCases.map { ($0.rawValue, settingsTexts.metricLabel($0)) },
            selected: config.resolvedTitleMetric.rawValue
        )
        configurePopup(
            rangePopup,
            items: UsageTimeRange.allCases.map { ($0.rawValue, $0.label(texts: texts)) },
            selected: config.resolvedTimeRange.rawValue
        )
    }

    private func configureControlsIfNeeded() {
        if adapterControls.isEmpty {
            configureControls()
        }
    }

    private func makeAdapterControls(adapter: AdapterConfig) -> AdapterConfigControls {
        let controls = AdapterConfigControls(adapter: adapter)
        configurePopup(
            controls.platformPopup,
            items: MonitorPlatform.allCases.map { ($0.rawValue, $0.displayName) },
            selected: adapter.platform.rawValue
        )
        controls.platformPopup.target = self
        controls.platformPopup.action = #selector(adapterPlatformChanged(_:))
        configureField(controls.nameField, value: adapter.name ?? adapter.displayName)
        configureField(controls.baseURLField, value: adapter.baseURL)
        configureField(controls.keyField, value: adapter.managementKey, constrainWidth: false)
        configureField(controls.visibleKeyField, value: adapter.managementKey, constrainWidth: false)
        controls.visibleKeyField.isHidden = true
        configureField(controls.userIDField, value: adapter.newApiUserID.map(String.init) ?? "")
        controls.userIDField.placeholderString = "1"
        controls.userIDField.alignment = .right
        controls.enabledButton.state = adapter.isEnabled ? .on : .off
        controls.enabledButton.target = self
        controls.enabledButton.action = #selector(adapterEnabledChanged(_:))
        controls.showKeyButton.title = settingsTexts.show
        controls.showKeyButton.target = self
        controls.showKeyButton.action = #selector(toggleAdapterKeyVisibility(_:))
        controls.showKeyButton.translatesAutoresizingMaskIntoConstraints = false
        controls.showKeyButton.widthAnchor.constraint(equalToConstant: 64).isActive = true
        controls.showKeyButton.heightAnchor.constraint(equalToConstant: Layout.adapterTextFieldHeight).isActive = true
        RelayTheme.styleButton(controls.showKeyButton, tint: RelayTheme.cyan)
        return controls
    }

    private func newAdapterControls() -> AdapterConfigControls {
        let platform = MonitorPlatform.sub2api
        let adapter = AdapterConfig(
            id: UUID().uuidString,
            name: uniqueAdapterName(for: platform),
            enabled: true,
            platform: platform,
            baseURL: "",
            managementKey: "",
            authHeaderName: platform.defaultAuthHeaderName,
            newApiUserID: nil,
            monitoringPath: platform.defaultMonitoringPath
        )
        return makeAdapterControls(adapter: adapter)
    }

    private func uniqueAdapterName(for platform: MonitorPlatform) -> String {
        let existingNames = Set(adapterControls.map { $0.displayName })
        let baseName = platform.displayName
        if !existingNames.contains(baseName) {
            return baseName
        }

        var index = 2
        while existingNames.contains("\(baseName) \(index)") {
            index += 1
        }
        return "\(baseName) \(index)"
    }

    private func buildHeader() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 34, left: 28, bottom: 18, right: 28)
        stack.wantsLayer = true
        stack.layer?.backgroundColor = RelayTheme.background.cgColor

        let title = label(settingsTexts.title, size: 20, weight: .black, color: RelayTheme.accent)
        title.alignment = .center
        let subtitle = label(
            settingsTexts.subtitle,
            size: 12,
            weight: .bold,
            color: RelayTheme.muted
        )
        subtitle.alignment = .center
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
            title: texts.adapters,
            rows: [
                adaptersListView(),
                formRow(title: texts.refreshIntervalSeconds, control: refreshIntervalField)
            ]
        ))

        content.addArrangedSubview(section(
            title: settingsTexts.displaySection,
            rows: [
                formRow(title: settingsTexts.language, control: languagePopup),
                formRow(title: settingsTexts.menuBarTitle, control: titlePopup),
                formRow(title: texts.range, control: rangePopup)
            ]
        ))

        content.addArrangedSubview(section(
            title: settingsTexts.cardsSection,
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
        scrollContentStack = content
        settingsDocument = document
        updateDocumentHeight()

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

    private func updateDocumentHeight() {
        guard let content = scrollContentStack, let document = settingsDocument else { return }
        content.needsLayout = true
        content.layoutSubtreeIfNeeded()
        let fittingHeight = max(ceil(content.fittingSize.height), 1)
        document.setFrameSize(NSSize(width: Layout.windowWidth, height: fittingHeight))
    }

    private func updateWindowSize(allowGrowth: Bool) {
        guard let window else { return }
        let screenMaxHeight = (window.screen ?? NSScreen.main)?.visibleFrame.height ?? 760
        let maxHeight = min(760, screenMaxHeight)
        window.maxSize = NSSize(width: Layout.windowWidth, height: maxHeight)

        let contentHeight = desiredContentHeight()
        let targetHeight = min(max(contentHeight, Layout.windowSize.height), maxHeight)
        if allowGrowth {
            let currentSize = window.contentLayoutRect.size
            guard targetHeight > currentSize.height else { return }
            window.setContentSize(NSSize(width: Layout.windowWidth, height: targetHeight))
        } else {
            window.setContentSize(NSSize(width: Layout.windowWidth, height: targetHeight))
        }
    }

    private func desiredContentHeight() -> CGFloat {
        let headerHeight = headerView?.fittingSize.height ?? 0
        let documentHeight = settingsDocument?.frame.height ?? 0
        let footerHeight = footerView?.fittingSize.height ?? 0
        let measuredHeight = headerHeight + documentHeight + footerHeight
        return measuredHeight > 0 ? ceil(measuredHeight) : Layout.windowSize.height
    }

    private func buildFooter() -> NSView {
        let footer = RelayBackgroundView()

        let actions = NSStackView()
        actions.orientation = .horizontal
        actions.alignment = .centerY
        actions.spacing = 10
        actions.translatesAutoresizingMaskIntoConstraints = false

        let updateButton = NSButton(title: texts.checkForUpdates, target: self, action: #selector(checkForUpdates))
        let cancelButton = NSButton(title: settingsTexts.cancel, target: self, action: #selector(cancel))
        let saveButton = NSButton(title: settingsTexts.save, target: self, action: #selector(save))
        saveButton.keyEquivalent = "\r"
        for button in [updateButton, cancelButton, saveButton] {
            button.translatesAutoresizingMaskIntoConstraints = false
            button.heightAnchor.constraint(equalToConstant: 30).isActive = true
        }
        updateButton.widthAnchor.constraint(equalToConstant: 128).isActive = true
        cancelButton.widthAnchor.constraint(equalToConstant: 58).isActive = true
        saveButton.widthAnchor.constraint(equalToConstant: 58).isActive = true
        RelayTheme.styleButton(updateButton, tint: RelayTheme.cyan, fontSize: 11)
        RelayTheme.styleButton(cancelButton, tint: RelayTheme.muted, fontSize: 11)
        RelayTheme.styleButton(saveButton, tint: RelayTheme.accent, fontSize: 11)

        actions.addArrangedSubview(updateButton)
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
        panel.setContentCompressionResistancePriority(.required, for: .vertical)
        panel.widthAnchor.constraint(equalToConstant: Layout.contentWidth).isActive = true

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(stack)

        stack.addArrangedSubview(label(title.uppercased(), size: 13, weight: .bold, color: RelayTheme.accent))
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

        let titleLabel = label(title, size: 12, weight: .bold, color: RelayTheme.muted)
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

    private func adaptersListView() -> NSView {
        refreshAdaptersList(keepScrollPosition: false)
        return adaptersStack
    }

    private func refreshAdaptersList(keepScrollPosition: Bool) {
        let previousOrigin = scrollView?.contentView.bounds.origin
        adaptersStack.arrangedSubviews.forEach { view in
            adaptersStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        for controls in adapterControls {
            adaptersStack.addArrangedSubview(adapterPanel(controls))
        }
        adaptersStack.addArrangedSubview(addAdapterButton())
        adaptersStack.needsLayout = true
        adaptersStack.layoutSubtreeIfNeeded()
        updateDocumentHeight()
        updateWindowSize(allowGrowth: true)
        restoreScrollOrigin(previousOrigin, when: keepScrollPosition)
    }

    private func restoreScrollOrigin(_ origin: NSPoint?, when shouldRestore: Bool) {
        guard shouldRestore, let origin, let scrollView else { return }
        let clipView = scrollView.contentView
        let maxY = max(0, (scrollView.documentView?.frame.height ?? 0) - clipView.bounds.height)
        clipView.scroll(to: NSPoint(x: origin.x, y: min(origin.y, maxY)))
        scrollView.reflectScrolledClipView(clipView)
    }

    private func adapterPanel(_ controls: AdapterConfigControls) -> NSView {
        let panel = AdapterPanelView()
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.setContentCompressionResistancePriority(.required, for: .vertical)
        panel.widthAnchor.constraint(equalToConstant: Layout.contentWidth - 32).isActive = true

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 12, bottom: 14, right: 12)
        stack.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            stack.topAnchor.constraint(equalTo: panel.topAnchor),
            stack.bottomAnchor.constraint(equalTo: panel.bottomAnchor)
        ])

        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 8
        header.translatesAutoresizingMaskIntoConstraints = false
        header.heightAnchor.constraint(equalToConstant: Layout.adapterHeaderHeight).isActive = true
        controls.enabledButton.title = settingsTexts.enabled
        header.addArrangedSubview(controls.enabledButton)
        header.addArrangedSubview(controls.platformPopup)
        header.addArrangedSubview(NSView())
        header.addArrangedSubview(deleteAdapterButton(controls))
        stack.addArrangedSubview(header)

        stack.addArrangedSubview(compactFormRow(title: texts.adapterName, control: controls.nameField))
        stack.addArrangedSubview(compactFormRow(title: texts.baseURL, control: controls.baseURLField))
        stack.addArrangedSubview(compactFormRow(title: texts.managementKey, control: adapterKeyControl(controls)))
        let userIDRow = compactFormRow(title: texts.newApiUserID, control: controls.userIDField)
        userIDRow.isHidden = controls.selectedPlatform != .newApi
        controls.userIDRow = userIDRow
        stack.addArrangedSubview(userIDRow)

        controls.fieldsContainer = stack
        updateAdapterControlsEnabled(controls)
        panel.contentStack = stack
        return panel
    }

    private func addAdapterButton() -> NSView {
        let button = NSButton(title: settingsTexts.addAdapter, target: self, action: #selector(addAdapter))
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 30).isActive = true
        button.widthAnchor.constraint(equalToConstant: 168).isActive = true
        RelayTheme.styleButton(button, tint: RelayTheme.up, fontSize: 11)

        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.edgeInsets = NSEdgeInsets(top: 2, left: 0, bottom: 0, right: 0)
        row.addArrangedSubview(button)
        return row
    }

    private func deleteAdapterButton(_ controls: AdapterConfigControls) -> NSButton {
        let button = NSButton(title: settingsTexts.delete, target: self, action: #selector(deleteAdapter(_:)))
        button.tag = adapterControls.firstIndex { $0 === controls } ?? -1
        button.isEnabled = adapterControls.count > 1
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 58).isActive = true
        button.heightAnchor.constraint(equalToConstant: 30).isActive = true
        RelayTheme.styleButton(button, tint: RelayTheme.down, fontSize: 11)
        return button
    }

    private func adapterKeyControl(_ controls: AdapterConfigControls) -> NSView {
        let fieldContainer = NSView()
        fieldContainer.translatesAutoresizingMaskIntoConstraints = false
        fieldContainer.addSubview(controls.keyField)
        fieldContainer.addSubview(controls.visibleKeyField)
        NSLayoutConstraint.activate([
            fieldContainer.widthAnchor.constraint(equalToConstant: Layout.adapterKeyFieldWidth),
            fieldContainer.heightAnchor.constraint(equalToConstant: Layout.adapterTextFieldHeight),
            controls.keyField.leadingAnchor.constraint(equalTo: fieldContainer.leadingAnchor),
            controls.keyField.trailingAnchor.constraint(equalTo: fieldContainer.trailingAnchor),
            controls.keyField.heightAnchor.constraint(equalTo: fieldContainer.heightAnchor),
            controls.keyField.centerYAnchor.constraint(equalTo: fieldContainer.centerYAnchor),
            controls.visibleKeyField.leadingAnchor.constraint(equalTo: fieldContainer.leadingAnchor),
            controls.visibleKeyField.trailingAnchor.constraint(equalTo: fieldContainer.trailingAnchor),
            controls.visibleKeyField.heightAnchor.constraint(equalTo: fieldContainer.heightAnchor),
            controls.visibleKeyField.centerYAnchor.constraint(equalTo: fieldContainer.centerYAnchor)
        ])

        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false
        row.heightAnchor.constraint(equalToConstant: Layout.adapterTextFieldHeight).isActive = true
        row.addArrangedSubview(fieldContainer)
        row.addArrangedSubview(controls.showKeyButton)
        return row
    }

    private func compactFormRow(title: String, control: NSView) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false
        row.heightAnchor.constraint(greaterThanOrEqualToConstant: Layout.adapterTextFieldHeight).isActive = true
        let titleLabel = label(title, size: 12, weight: .bold, color: RelayTheme.muted)
        titleLabel.widthAnchor.constraint(equalToConstant: Layout.adapterLabelWidth).isActive = true
        row.addArrangedSubview(titleLabel)
        row.addArrangedSubview(control)
        return row
    }

    private func checkbox(for item: DisplayItem, enabledItems: Set<DisplayItem>) -> NSButton {
        let button = NSButton(checkboxWithTitle: settingsTexts.itemLabel(item), target: nil, action: nil)
        button.state = enabledItems.contains(item) ? .on : .off
        button.font = RelayTheme.font(size: 12, weight: .bold)
        button.contentTintColor = RelayTheme.accent
        button.lineBreakMode = .byTruncatingTail
        itemButtons[item] = button
        return button
    }

    private func hintLabel() -> NSTextField {
        let hint = label(settingsTexts.adaptersHint, size: 11, weight: .bold, color: RelayTheme.muted)
        hint.maximumNumberOfLines = 2
        hint.lineBreakMode = .byTruncatingTail
        hint.widthAnchor.constraint(equalToConstant: Layout.contentWidth - 32).isActive = true
        return hint
    }

    private func configurePopup(_ popup: PixelPopupButton, items: [(String, String)], selected: String) {
        popup.removeAllItems()
        for item in items {
            popup.addItem(title: item.1, representedObject: item.0)
        }
        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.widthAnchor.constraint(equalToConstant: Layout.controlWidth).isActive = true
        popup.heightAnchor.constraint(equalToConstant: Layout.adapterTextFieldHeight).isActive = true
        popup.selectRepresentedObject(selected)
        popup.applyPixelStyle()
    }

    private func configureField(_ field: NSTextField, value: String, constrainWidth: Bool = true) {
        field.stringValue = value
        RelayTheme.styleField(field)
        field.isEditable = true
        field.isSelectable = true
        field.isEnabled = true
        field.refusesFirstResponder = false
        field.cell?.isEditable = true
        field.cell?.isSelectable = true
        field.controlSize = .regular
        field.usesSingleLineMode = true
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        field.lineBreakMode = .byTruncatingTail
        field.translatesAutoresizingMaskIntoConstraints = false
        field.heightAnchor.constraint(equalToConstant: Layout.adapterTextFieldHeight).isActive = true
        field.cell?.controlSize = .regular
        if constrainWidth {
            field.widthAnchor.constraint(equalToConstant: Layout.controlWidth).isActive = true
        }
    }

    private func label(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor = RelayTheme.text) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = RelayTheme.font(size: size, weight: weight)
        field.textColor = color
        field.lineBreakMode = .byTruncatingTail
        return field
    }

    @objc private func save() {
        if let interval = TimeInterval(refreshIntervalField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) {
            config.refreshIntervalSeconds = interval
        }
        let adapters = adapterControls.map(adapterFromControls)
        config.adapters = adapters
        syncPrimaryFields(from: adapters.first(where: { $0.isEnabled }) ?? adapters.first)
        config.language = AppLanguage(rawValue: selectedValue(languagePopup))
        config.titleMetric = DisplayMetric(rawValue: selectedValue(titlePopup))
        config.timeRange = UsageTimeRange(rawValue: selectedValue(rangePopup))
        config.activityPeriod = config.resolvedActivityPeriod
        config.display = config.titleMetric?.rawValue
        config.listItems = DisplayItem.allCases.filter { itemButtons[$0]?.state == .on }
        onSave(config)
        close()
    }

    private func adapterFromControls(_ controls: AdapterConfigControls) -> AdapterConfig {
        let platform = controls.selectedPlatform
        let userIDText = controls.userIDField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = controls.nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return AdapterConfig(
            id: controls.adapterID,
            name: name.isEmpty ? nil : name,
            enabled: controls.enabledButton.state == .on,
            platform: platform,
            baseURL: controls.baseURLField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
            managementKey: currentKey(controls),
            authHeaderName: platform.defaultAuthHeaderName,
            newApiUserID: userIDText.isEmpty ? nil : Int(userIDText),
            monitoringPath: controls.monitoringPath ?? platform.defaultMonitoringPath
        )
    }

    private func syncPrimaryFields(from adapter: AdapterConfig?) {
        guard let adapter else { return }
        config.platform = adapter.platform
        config.baseURL = adapter.baseURL
        config.managementKey = adapter.managementKey
        config.authHeaderName = adapter.authHeaderName
        config.newApiUserID = adapter.newApiUserID
        config.monitoringPath = adapter.monitoringPath
    }

    @objc private func cancel() {
        close()
    }

    @objc private func checkForUpdates() {
        onCheckForUpdates()
    }

    private func selectedValue(_ popup: PixelPopupButton) -> String {
        popup.selectedRepresentedObject as? String ?? ""
    }

    private func currentKey(_ controls: AdapterConfigControls) -> String {
        controls.isKeyVisible ? controls.visibleKeyField.stringValue : controls.keyField.stringValue
    }

    @objc private func adapterEnabledChanged(_ sender: NSButton) {
        guard let controls = adapterControls.first(where: { $0.enabledButton === sender }) else { return }
        updateAdapterControlsEnabled(controls)
    }

    private func updateAdapterControlsEnabled(_ controls: AdapterConfigControls) {
        let enabled = controls.enabledButton.state == .on
        controls.nameField.isEnabled = enabled
        controls.baseURLField.isEnabled = enabled
        controls.keyField.isEnabled = enabled
        controls.visibleKeyField.isEnabled = enabled
        controls.userIDField.isEnabled = enabled
        controls.showKeyButton.isEnabled = enabled
        controls.showKeyButton.alphaValue = enabled ? 1 : 0.45
    }

    @objc private func toggleAdapterKeyVisibility(_ sender: NSButton) {
        guard let controls = adapterControls.first(where: { $0.showKeyButton === sender }) else { return }
        controls.isKeyVisible.toggle()
        if controls.isKeyVisible {
            controls.visibleKeyField.stringValue = controls.keyField.stringValue
        } else {
            controls.keyField.stringValue = controls.visibleKeyField.stringValue
        }
        controls.keyField.isHidden = controls.isKeyVisible
        controls.visibleKeyField.isHidden = !controls.isKeyVisible
        controls.showKeyButton.title = controls.isKeyVisible ? settingsTexts.hide : settingsTexts.show
        RelayTheme.styleButton(controls.showKeyButton, tint: RelayTheme.cyan)
    }

    @objc private func adapterPlatformChanged(_ sender: PixelPopupButton) {
        guard let controls = adapterControls.first(where: { $0.platformPopup === sender }) else { return }
        let platform = controls.selectedPlatform
        controls.userIDRow?.isHidden = platform != .newApi
        if controls.nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            controls.nameField.stringValue = platform.displayName
        }
        controls.monitoringPath = platform.defaultMonitoringPath
        updateDocumentHeight()
        updateWindowSize(allowGrowth: true)
    }

    @objc private func addAdapter() {
        adapterControls.append(newAdapterControls())
        refreshAdaptersList(keepScrollPosition: true)
    }

    @objc private func deleteAdapter(_ sender: NSButton) {
        guard adapterControls.count > 1, adapterControls.indices.contains(sender.tag) else { return }
        adapterControls.remove(at: sender.tag)
        refreshAdaptersList(keepScrollPosition: true)
    }
}

private final class AdapterConfigControls {
    let id = UUID().uuidString
    let adapterID: String
    var monitoringPath: String?
    let enabledButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    let platformPopup = PixelPopupButton()
    let nameField = PixelTextField()
    let baseURLField = PixelTextField()
    let keyField = PixelSecureField()
    let visibleKeyField = PixelTextField()
    let showKeyButton = NSButton()
    let userIDField = PixelTextField()
    weak var userIDRow: NSView?
    weak var fieldsContainer: NSView?
    var isKeyVisible = false

    init(adapter: AdapterConfig) {
        adapterID = adapter.id ?? UUID().uuidString
        monitoringPath = adapter.monitoringPath
    }

    var selectedPlatform: MonitorPlatform {
        guard
            let rawValue = platformPopup.selectedRepresentedObject as? String,
            let platform = MonitorPlatform(rawValue: rawValue)
        else {
            return .cliproxyapiPro
        }
        return platform
    }

    var displayName: String {
        let explicit = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !explicit.isEmpty {
            return explicit
        }
        return selectedPlatform.displayName
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
        layer?.cornerRadius = 0
        layer?.borderWidth = 1
        layer?.borderColor = RelayTheme.line.cgColor
        layer?.backgroundColor = RelayTheme.raised.cgColor
    }

    required init?(coder: NSCoder) {
        nil
    }
}

private final class AdapterPanelView: NSView {
    weak var contentStack: NSStackView?

    override var intrinsicContentSize: NSSize {
        let height = contentStack?.fittingSize.height ?? NSView.noIntrinsicMetric
        return NSSize(width: NSView.noIntrinsicMetric, height: height)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 0
        layer?.borderWidth = 1
        layer?.borderColor = RelayTheme.line.withAlphaComponent(0.75).cgColor
        layer?.backgroundColor = RelayTheme.background.cgColor
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
