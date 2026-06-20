import AppKit

extension MenuBarApp: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        logger.info("menu will open language=\((config?.resolvedLanguage ?? .english).rawValue) hasSnapshot=\(lastSnapshot != nil)")
        if let lastSnapshot {
            showSnapshot(lastSnapshot)
        } else {
            applyListVisibility()
        }
    }
}
