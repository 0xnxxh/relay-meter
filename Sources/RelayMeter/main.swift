import AppKit
import Foundation
import ServiceManagement
import Sparkle

@MainActor
final class MenuBarApp: NSObject, NSApplicationDelegate {
    private static let outsideCloseStatusToggleSuppressionSeconds: TimeInterval = 1.5

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
    private let configStore = ConfigStore()
    let logger = AppLogger.shared
    private var client: UsageClient?
    var config: AppConfig?
    private var refreshTimer: Timer?
    private var settingsWindow: SettingsWindowController?
    private var activityWindow: ActivityWindowController?
    var lastSnapshot: UsageDashboardSnapshot?
    private var selectedSnapshotSourceID = UsageDashboardSnapshot.aggregateSourceID
    private var mainPanel: NSPanel?
    private var panelContentView: NSStackView?
    private var snapshotView: SnapshotMenuView?
    private var footerView: MenuFooterView?
    private var isMainPanelPresented = false
    private var outsideClickMonitor: Any?
    private var suppressNextStatusOpenAfterOutsideClose = false
    private var configWatcher: DispatchSourceFileSystemObject?
    private var configWatchDescriptor: CInt = -1
    private var configReloadWorkItem: DispatchWorkItem?
    private var isSavingConfig = false
    private var refreshGeneration = 0
    private var needsSnapshotRender = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureApplicationMenu()
        logger.info("app launch log=\(logger.url.path)")
        loadConfigAndStart()
    }

    private func configureApplicationMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let editMenuItem = NSMenuItem()

        mainMenu.addItem(appMenuItem)
        mainMenu.addItem(editMenuItem)

        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "Quit Relay Meter", action: #selector(quit), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu

        NSApp.mainMenu = mainMenu
    }

    private func configureMenu() {
        statusItem.button?.title = "RM --"
        statusItem.button?.target = self
        statusItem.button?.action = #selector(toggleMainPanel(_:))
        statusItem.menu = nil
        configureMainPanelIfNeeded()
        renderSnapshotMenuView()
        if let lastSnapshot {
            showSnapshot(lastSnapshot)
        }
    }

    private func configureMainPanelIfNeeded() {
        guard mainPanel == nil else { return }
        let content = NSStackView()
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 0
        content.translatesAutoresizingMaskIntoConstraints = false
        content.wantsLayer = true
        content.layer?.backgroundColor = RelayTheme.background.cgColor

        let container = RelayBackgroundView()
        container.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            content.topAnchor.constraint(equalTo: container.topAnchor)
        ])

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 640),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = container
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.isOpaque = false
        panel.isReleasedWhenClosed = false
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        mainPanel = panel
        panelContentView = content
    }

    private func loadConfigAndStart() {
        do {
            let config = try configStore.load()
            logger.info("config loaded \(configSummary(config))")
            applyConfig(config, refresh: true)
            startConfigWatcher()
        } catch {
            logger.error("config load failed \(error.localizedDescription)")
            showError(error.localizedDescription)
        }
    }

    private func applyConfig(_ nextConfig: AppConfig, refresh: Bool) {
        logger.info("apply config refresh=\(refresh) \(configSummary(nextConfig))")
        config = nextConfig
        client = UsageClient(config: nextConfig, logger: logger)
        refreshGeneration += 1
        configureMenu()
        scheduleRefresh(interval: nextConfig.refreshInterval)
        if refresh {
            refreshNow()
        }
    }

    private func startConfigWatcher() {
        configWatcher?.cancel()
        if configWatchDescriptor >= 0 {
            close(configWatchDescriptor)
        }
        configWatchDescriptor = open(configStore.url.path, O_EVTONLY)
        guard configWatchDescriptor >= 0 else {
            logger.error("config watcher open failed path=\(configStore.url.path)")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: configWatchDescriptor,
            eventMask: [.write, .delete, .rename, .attrib, .extend],
            queue: DispatchQueue.main
        )
        source.setEventHandler { [weak self] in
            self?.scheduleConfigReload()
        }
        source.setCancelHandler { [weak self] in
            guard let self, self.configWatchDescriptor >= 0 else { return }
            close(self.configWatchDescriptor)
            self.configWatchDescriptor = -1
        }
        configWatcher = source
        source.resume()
        logger.info("config watcher started path=\(configStore.url.path)")
    }

    private func scheduleConfigReload() {
        guard !isSavingConfig else {
            logger.info("config reload skipped self-save")
            return
        }
        logger.info("config file change detected")
        configReloadWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.reloadConfigFromDisk()
        }
        configReloadWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: item)
    }

    private func reloadConfigFromDisk() {
        do {
            let nextConfig = try configStore.load()
            logger.info("config reloaded \(configSummary(nextConfig))")
            applyConfig(nextConfig, refresh: true)
            startConfigWatcher()
        } catch {
            logger.error("config reload failed \(error.localizedDescription)")
            showError(error.localizedDescription)
        }
    }

    private func scheduleRefresh(interval: TimeInterval) {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshNow() }
        }
        logger.info("refresh scheduled interval=\(interval)")
    }

    @objc private func refreshNow() {
        guard let client else {
            logger.info("refresh requested without client")
            loadConfigAndStart()
            return
        }

        if lastSnapshot == nil {
            let texts = TextBundle.forLanguage(config?.resolvedLanguage ?? .english)
            statusItem.button?.title = "RM \(texts.loading)"
            renderSnapshotMenuView()
        }
        refreshGeneration += 1
        let generation = refreshGeneration
        Task { @MainActor in
            do {
                let snapshot = try await client.fetchDashboardSnapshot()
                guard generation == self.refreshGeneration else {
                    self.logger.info("refresh ignored stale generation=\(generation) current=\(self.refreshGeneration) range=\(snapshot.selectedRange.rawValue)")
                    return
                }
                self.logger.info("refresh ok range=\(snapshot.selectedRange.rawValue) health=\(snapshot.health.label) requests=\(snapshot.aggregate.scope.totalRequests) failures=\(snapshot.aggregate.scope.failureCount) adapters=\(snapshot.adapters.count) errors=\(snapshot.errors.count)")
                self.showSnapshot(snapshot)
            } catch {
                guard generation == self.refreshGeneration else {
                    self.logger.info("refresh error ignored stale generation=\(generation) current=\(self.refreshGeneration)")
                    return
                }
                self.logger.error("refresh failed \(error.localizedDescription)")
                self.showError(error.localizedDescription)
            }
        }
    }

    func showSnapshot(_ snapshot: UsageDashboardSnapshot) {
        lastSnapshot = snapshot
        ensureSelectedSnapshotExists(in: snapshot)
        renderMenuTitle(for: snapshot)
        renderSnapshotMenuView()
    }

    private func showError(_ message: String) {
        let texts = TextBundle.forLanguage(config?.resolvedLanguage ?? .english)
        statusItem.button?.title = "RM !"
        statusItem.button?.toolTip = "\(texts.error): \(message)"
    }

    private func menuTitle(for snapshot: UsageDashboardSnapshot) -> String {
        let texts = TextBundle.forLanguage(config?.resolvedLanguage ?? .english)
        let aggregate = snapshot.aggregate
        switch config?.resolvedTitleMetric ?? .requests {
        case .tokens: return title(snapshot, MenuValueFormatter.compact(aggregate.scope.totalTokens))
        case .failures: return title(snapshot, "\(MenuValueFormatter.compact(aggregate.scope.failureCount)) \(texts.failures)")
        case .successRate: return title(snapshot, MenuValueFormatter.percent(aggregate.scope.successRate))
        case .latency: return title(snapshot, aggregate.scope.avgLatencyMs.map(MenuValueFormatter.duration) ?? "--")
        case .cache: return title(snapshot, "\(MenuValueFormatter.compact(aggregate.scope.cacheTokens)) \(texts.cacheUnit)")
        case .recent: return title(snapshot, "\(MenuValueFormatter.compact(aggregate.recent.totalRequests)) / \(texts.last15m)")
        case .cost: return title(snapshot, aggregate.scope.costUSD.map(MenuValueFormatter.currencyUSD) ?? "--")
        case .requests: return title(snapshot, "\(MenuValueFormatter.compact(aggregate.scope.totalRequests)) / \(MenuValueFormatter.percent(aggregate.scope.successRate))")
        }
    }

    private func title(_ snapshot: UsageDashboardSnapshot, _ value: String) -> String {
        snapshot.adapters.count > 1 ? "● \(value) · \(snapshot.adapters.count)" : "● \(value)"
    }

    private func renderMenuTitle(for snapshot: UsageDashboardSnapshot) {
        let attributed = NSMutableAttributedString(string: menuTitle(for: snapshot))
        attributed.addAttribute(.foregroundColor, value: RelayTheme.healthColor(snapshot.health), range: NSRange(location: 0, length: 1))
        attributed.addAttribute(.foregroundColor, value: RelayTheme.text, range: NSRange(location: 2, length: attributed.length - 2))
        statusItem.button?.attributedTitle = attributed
        statusItem.button?.toolTip = "\(snapshot.health.label(language: config?.resolvedLanguage ?? .english)) · \(snapshot.adapters.count) adapters"
    }

    func applyListVisibility() {
        renderSnapshotMenuView()
    }

    private func renderSnapshotMenuView() {
        // The panel is a menu bar popover: rebuilding its view tree while hidden is wasted work.
        guard isMainPanelPresented || mainPanel?.isVisible == true || snapshotView == nil else {
            needsSnapshotRender = true
            return
        }
        needsSnapshotRender = false
        let texts = TextBundle.forLanguage(config?.resolvedLanguage ?? .english)
        let selectRange: (UsageTimeRange) -> Void = { [weak self] in self?.selectTimeRangeTab($0) }
        let selectSource: (String) -> Void = { [weak self] in self?.selectSnapshotSource($0) }
        let refresh: () -> Void = { [weak self] in self?.refreshNow() }
        let openMonitoring: () -> Void = { [weak self] in self?.openMonitoringPage() }
        let openActivityDetails: () -> Void = { [weak self] in self?.openActivityDetails() }
        if let lastSnapshot {
            snapshotView = SnapshotMenuView(
                dashboard: lastSnapshot,
                config: config,
                texts: texts,
                selectedSourceID: selectedSnapshotSourceID,
                onRangeSelected: selectRange,
                onOpenActivityDetails: openActivityDetails,
                onSourceSelected: selectSource,
                onRefresh: refresh,
                onOpenMonitoring: openMonitoring
            )
        } else {
            snapshotView = SnapshotMenuView.loading(
                texts: texts,
                config: config,
                selectedRange: config?.resolvedTimeRange ?? .today,
                selectedSourceID: selectedSnapshotSourceID,
                onRangeSelected: selectRange,
                onOpenActivityDetails: openActivityDetails,
                onSourceSelected: selectSource,
                onRefresh: refresh,
                onOpenMonitoring: openMonitoring
            )
        }
        footerView = MenuFooterView(
            texts: texts,
            onSettings: { [weak self] in self?.openSettings() },
            onQuit: { [weak self] in self?.quit() }
        )
        rebuildPanelContent()
    }

    private func rebuildPanelContent() {
        guard let content = panelContentView, let snapshotView, let footerView else { return }
        content.arrangedSubviews.forEach { view in
            content.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        content.addArrangedSubview(snapshotView)
        content.addArrangedSubview(footerView)
        snapshotView.translatesAutoresizingMaskIntoConstraints = false
        footerView.translatesAutoresizingMaskIntoConstraints = false
        snapshotView.heightAnchor.constraint(equalToConstant: snapshotView.frame.height).isActive = true
        footerView.heightAnchor.constraint(equalToConstant: footerView.frame.height).isActive = true
        content.layoutSubtreeIfNeeded()
        let height = ceil(snapshotView.frame.height + footerView.frame.height)
        mainPanel?.setContentSize(NSSize(width: 380, height: height))
        if isMainPanelPresented {
            alignMainPanelWindow()
        }
    }

    @objc private func toggleMainPanel(_ sender: NSStatusBarButton) {
        if isMainPanelPresented || mainPanel?.isVisible == true {
            hideMainPanel()
            return
        }
        guard !suppressNextStatusOpenAfterOutsideClose else {
            suppressNextStatusOpenAfterOutsideClose = false
            return
        }

        showMainPanel()
    }

    private func showMainPanel() {
        configureMainPanelIfNeeded()
        if needsSnapshotRender {
            renderSnapshotMenuView()
        }
        alignMainPanelWindow()
        mainPanel?.orderFrontRegardless()
        isMainPanelPresented = true
        installOutsideClickMonitor()
    }

    private func hideMainPanel() {
        isMainPanelPresented = false
        mainPanel?.orderOut(nil)
        removeOutsideClickMonitor()
    }

    private func alignMainPanelWindow() {
        guard let panel = mainPanel, let button = statusItem.button, let buttonWindow = button.window else { return }
        let buttonFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let visibleFrame = buttonWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let panelSize = panel.frame.size
        var x = buttonFrame.midX - panelSize.width / 2
        x = min(max(x, visibleFrame.minX + 8), visibleFrame.maxX - panelSize.width - 8)
        let y = buttonFrame.minY - panelSize.height - 6
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func installOutsideClickMonitor() {
        removeOutsideClickMonitor()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            DispatchQueue.main.async {
                self?.closeMainPanelIfClickIsOutside(event)
            }
        }
    }

    private func closeMainPanelIfClickIsOutside(_ event: NSEvent) {
        guard let panel = mainPanel, isMainPanelPresented || panel.isVisible else {
            removeOutsideClickMonitor()
            return
        }
        let point = screenPoint(for: event)
        guard !panel.frame.contains(point) else { return }
        suppressNextStatusOpenAfterOutsideClose = true
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.outsideCloseStatusToggleSuppressionSeconds) { [weak self] in
            self?.suppressNextStatusOpenAfterOutsideClose = false
        }
        hideMainPanel()
    }

    private func removeOutsideClickMonitor() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
    }

    private func screenPoint(for event: NSEvent) -> NSPoint {
        guard let window = event.window else {
            return event.locationInWindow
        }
        return window.convertPoint(toScreen: event.locationInWindow)
    }

    private func selectTimeRangeTab(_ range: UsageTimeRange) {
        guard var nextConfig = config, nextConfig.resolvedTimeRange != range else { return }
        nextConfig.timeRange = range
        do {
            isSavingConfig = true
            try configStore.save(nextConfig)
            isSavingConfig = false
            config = nextConfig
            client = UsageClient(config: nextConfig, logger: logger)
            refreshGeneration += 1
            lastSnapshot = nil
            logger.info("time range selected tab=\(range.rawValue)")
            let texts = TextBundle.forLanguage(nextConfig.resolvedLanguage)
            statusItem.button?.title = "RM \(texts.loading)"
            renderSnapshotMenuView()
            refreshNow()
        } catch {
            isSavingConfig = false
            logger.error("time range save failed \(error.localizedDescription)")
            showError(error.localizedDescription)
        }
    }

    private func selectSnapshotSource(_ sourceID: String) {
        selectedSnapshotSourceID = sourceID
        renderSnapshotMenuView()
        logger.info("snapshot source selected id=\(sourceID)")
    }

    private func ensureSelectedSnapshotExists(in snapshot: UsageDashboardSnapshot) {
        guard selectedSnapshotSourceID != UsageDashboardSnapshot.aggregateSourceID else { return }
        let available = snapshot.adapters.contains { $0.sourceID == selectedSnapshotSourceID }
        if !available {
            selectedSnapshotSourceID = UsageDashboardSnapshot.aggregateSourceID
        }
    }


    @objc private func openSettings() {
        guard let config else { return }
        let launchAtLoginStatus = SMAppService.mainApp.status
        let controller = SettingsWindowController(
            config: config,
            launchAtLoginEnabled: Self.launchAtLoginRequested(status: launchAtLoginStatus),
            launchAtLoginRequiresApproval: launchAtLoginStatus == .requiresApproval,
            onSave: { [weak self] nextConfig, launchAtLoginEnabled in
                self?.saveSettings(nextConfig, launchAtLoginEnabled: launchAtLoginEnabled)
            },
            onCheckForUpdates: { [weak self] in self?.checkForUpdates() }
        )
        settingsWindow = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func saveSettings(_ nextConfig: AppConfig, launchAtLoginEnabled: Bool) {
        do {
            isSavingConfig = true
            try configStore.save(nextConfig)
            isSavingConfig = false
            logger.info("settings saved \(configSummary(nextConfig))")
            applyConfig(nextConfig, refresh: true)
            startConfigWatcher()
        } catch {
            isSavingConfig = false
            logger.error("settings save failed \(error.localizedDescription)")
            showError(error.localizedDescription)
            return
        }

        if launchAtLoginEnabled != Self.launchAtLoginRequested(status: SMAppService.mainApp.status) {
            do {
                try Self.setLaunchAtLogin(enabled: launchAtLoginEnabled, language: nextConfig.resolvedLanguage)
            } catch {
                logger.error("launch at login update failed \(error.localizedDescription)")
                showError(error.localizedDescription)
            }
        }
    }

    private static func launchAtLoginRequested(status: SMAppService.Status) -> Bool {
        switch status {
        case .enabled, .requiresApproval:
            return true
        case .notRegistered, .notFound:
            return false
        @unknown default:
            return false
        }
    }

    private static func setLaunchAtLogin(enabled: Bool, language: AppLanguage) throws {
        let service = SMAppService.mainApp
        if enabled {
            switch service.status {
            case .enabled:
                return
            case .requiresApproval:
                SMAppService.openSystemSettingsLoginItems()
                throw LaunchAtLoginError.requiresApproval(language)
            case .notRegistered, .notFound:
                try service.register()
                if service.status == .requiresApproval {
                    SMAppService.openSystemSettingsLoginItems()
                    throw LaunchAtLoginError.requiresApproval(language)
                }
            @unknown default:
                try service.register()
            }
        } else {
            switch service.status {
            case .notRegistered, .notFound:
                return
            case .enabled, .requiresApproval:
                try service.unregister()
            @unknown default:
                try service.unregister()
            }
        }
    }

    @objc private func openMonitoringPage() {
        for url in config?.monitoringURLs(for: selectedSnapshotSourceID) ?? [] {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openActivityDetails() {
        guard let dashboard = lastSnapshot else { return }
        let controller = ActivityWindowController(
            dashboard: dashboard,
            selectedSourceID: selectedSnapshotSourceID,
            texts: TextBundle.forLanguage(config?.resolvedLanguage ?? .english)
        )
        activityWindow = controller
        hideMainPanel()
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    @objc private func quit() { NSApp.terminate(nil) }
}

private enum LaunchAtLoginError: LocalizedError {
    case requiresApproval(AppLanguage)

    var errorDescription: String? {
        switch self {
        case .requiresApproval(.chinese):
            "Relay Meter 需要在“系统设置 > 通用 > 登录项”中获得授权。"
        case .requiresApproval(.english):
            "Relay Meter needs approval in System Settings > General > Login Items."
        }
    }
}

let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { MenuBarApp() }
app.delegate = delegate
app.run()
