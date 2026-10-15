import AppKit
import FinderSync
import OSLog

final class FinderSync: FIFinderSync {
    private let logger = Logger(subsystem: "dev.jojo.FinderMenu", category: "Actions")
    // Finder forwards tags, but not representedObject. Capture the menu's targets.
    private var menuURLs: [URL] = []
    private var menuEntries: [Int: MenuEntry] = [:]

    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
        logger.notice("Finder extension started; pid=\(ProcessInfo.processInfo.processIdentifier)")
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        let controller = FIFinderSyncController.default()
        switch menuKind {
        case .contextualMenuForItems: menuURLs = controller.selectedItemURLs() ?? []
        case .contextualMenuForContainer, .contextualMenuForSidebar:
            menuURLs = controller.targetedURL().map { [$0] } ?? []
        default: return nil
        }
        menuEntries = [:]
        guard !menuURLs.isEmpty else { return nil }
        let configuration: MenuConfiguration
        do { configuration = try ConfigurationRepository().load() }
        catch {
            logger.error("Cannot load menu configuration: \(error.localizedDescription, privacy: .public)")
            let menu = NSMenu(title: "Finder Menu")
            let item = NSMenuItem(title: "Finder Menu：配置读取失败", action: nil, keyEquivalent: "")
            menu.addItem(item)
            return menu
        }
        let menu = NSMenu(title: "Finder Menu")
        menu.autoenablesItems = false
        for (index, entry) in configuration.entries.enumerated() where entry.applies(to: menuURLs) {
            let item = NSMenuItem(title: entry.title, action: #selector(performAction(_:)), keyEquivalent: "")
            item.tag = index
            item.target = self
            if entry.kind == .copyPaths {
                item.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
            } else if let app = entry.applicationURL {
                let icon = NSWorkspace.shared.icon(forFile: app.path)
                icon.size = NSSize(width: 16, height: 16)
                item.image = icon
            } else {
                item.isEnabled = false
                item.toolTip = "找不到这个应用，请在 Finder Menu 中重新添加。"
            }
            menuEntries[index] = entry
            menu.addItem(item)
        }
        logger.info("Menu loaded: count=\(menu.items.count)")
        return menu.items.isEmpty ? nil : menu
    }

    @objc private func performAction(_ sender: NSMenuItem) {
        guard let entry = menuEntries[sender.tag], !menuURLs.isEmpty else { return }
        if entry.kind == .copyPaths {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            let success = pasteboard.setString(menuURLs.map(\.path).joined(separator: "\n"), forType: .string)
            logger.notice("Copy paths: count=\(self.menuURLs.count), success=\(success)")
            if !success { showError("无法写入剪贴板，请重试。") }
            return
        }
        do {
            logger.notice("Opening app: \(entry.bundleIdentifier ?? "", privacy: .public)")
            let data = try JSONEncoder().encode(menuURLs.map(\.path))
            let app = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            let helper = app.appendingPathComponent("Contents/Helpers/FinderMenuOpener.app")
            let options = NSWorkspace.OpenConfiguration()
            options.activates = false
            options.createsNewApplicationInstance = true
            var request = URLComponents()
            request.scheme = "findermenu-open"
            request.host = "open"
            request.path = "/" + entry.id.uuidString
            request.queryItems = [URLQueryItem(name: "paths", value: data.base64EncodedString())]
            guard let requestURL = request.url else { throw ConfigurationError.invalid }
            NSWorkspace.shared.open([requestURL], withApplicationAt: helper, configuration: options) { [self] _, error in
                if let error {
                    logger.error("Open helper failed: \(error.localizedDescription, privacy: .public)")
                    DispatchQueue.main.async { self.showError(error.localizedDescription) }
                }
            }
        } catch { showError(error.localizedDescription) }
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Finder Menu"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
