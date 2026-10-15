import AppKit
import FinderMenuCore
import FinderSync
import OSLog

@MainActor
final class FinderSync: FIFinderSync {
    private let logger = Logger(subsystem: FinderMenuIdentity.logSubsystem, category: "Actions")
    private let preferences = PreferencesStore.shared
    // Finder forwards tags but not representedObject, so snapshot the targets and items per menu.
    private var menuURLs: [URL] = []
    private var menuItems: [MenuItem] = []

    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
        logger.notice("Finder extension started; pid=\(ProcessInfo.processInfo.processIdentifier)")
    }

    /// Finder calls both the menu and its actions on an XPC queue, not main; AppKit work hops to main.
    nonisolated override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        let started = ProcessInfo.processInfo.systemUptime
        // Neither self nor NSMenu is Sendable. Both are only touched on main while this thread waits.
        nonisolated(unsafe) let target = self
        nonisolated(unsafe) var menu: NSMenu?
        Self.onMain {
            menu = target.buildMenu(for: menuKind)
            target.logger.info("Menu loaded: count=\(menu?.items.count ?? 0), elapsed_ms=\((ProcessInfo.processInfo.systemUptime - started) * 1000)")
        }
        return menu
    }

    nonisolated private static func onMain(_ work: @MainActor () -> Void) {
        if Thread.isMainThread { MainActor.assumeIsolated(work) } else { DispatchQueue.main.sync { MainActor.assumeIsolated(work) } }
    }

    private func buildMenu(for menuKind: FIMenuKind) -> NSMenu? {
        let controller = FIFinderSyncController.default()
        switch menuKind {
        case .contextualMenuForItems: menuURLs = controller.selectedItemURLs() ?? []
        case .contextualMenuForContainer, .contextualMenuForSidebar: menuURLs = controller.targetedURL().map { [$0] } ?? []
        default: return nil
        }
        menuItems = []
        guard let selection = SelectionKind(classifying: menuURLs) else { return nil }

        let menu = NSMenu(title: "Finder Menu")
        menu.autoenablesItems = false
        let configuration: MenuConfiguration
        do { configuration = try preferences.loadConfiguration() } catch {
            logger.error("Cannot load menu configuration: \(error.localizedDescription, privacy: .public)")
            menu.addItem(withTitle: String(localized: "Finder Menu：配置读取失败"), action: nil, keyEquivalent: "")
            return menu
        }
        let canSign = preferences.signingKey() != nil
        menuItems = configuration.visibleItems(for: selection)
        for (index, item) in menuItems.enumerated() {
            let menuItem = NSMenuItem(title: item.title, action: #selector(performAction(_:)), keyEquivalent: "")
            menuItem.tag = index
            menuItem.target = self
            switch item.action {
            case .copyPaths:
                menuItem.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
            case .open(let application):
                if let url = ApplicationResolver.url(for: application) {
                    menuItem.image = ApplicationResolver.menuIcon(at: url)
                    if !canSign {
                        menuItem.isEnabled = false
                        menuItem.toolTip = String(localized: "请先打开一次 Finder Menu 以完成更新。")
                    }
                } else {
                    menuItem.isEnabled = false
                    menuItem.toolTip = String(localized: "找不到这个应用，请在 Finder Menu 中重新添加。")
                }
            }
            menu.addItem(menuItem)
        }
        return menu.items.isEmpty ? nil : menu
    }

    @objc nonisolated private func performAction(_ sender: NSMenuItem) {
        let tag = sender.tag
        nonisolated(unsafe) let target = self
        Self.onMain { target.perform(tag: tag) }
    }

    private func perform(tag: Int) {
        guard menuItems.indices.contains(tag), !menuURLs.isEmpty else { return }
        let item = menuItems[tag]
        switch item.action {
        case .copyPaths: copyPaths()
        case .open(let application): requestOpen(item: item, application: application)
        }
    }

    private func copyPaths() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let success = pasteboard.setString(menuURLs.map(\.path).joined(separator: "\n"), forType: .string)
        logger.notice("Copy paths: count=\(self.menuURLs.count), success=\(success)")
        if !success { Self.showError(String(localized: "无法写入剪贴板，请重试。")) }
    }

    /// The sandboxed extension cannot open files with another app directly, so it hands a signed
    /// request to the embedded, unsandboxed helper. The helper re-checks the saved configuration.
    private func requestOpen(item: MenuItem, application: ApplicationRef) {
        guard let key = preferences.signingKey() else {
            Self.showError(String(localized: "请先打开一次 Finder Menu 以完成更新。"))
            return
        }
        let requestURL: URL
        do { requestURL = try OpenRequest(itemID: item.id, paths: menuURLs.map(\.path)).signedURL(key: key) } catch {
            Self.showError(error.localizedDescription)
            return
        }
        logger.notice("Opening app: \(application.bundleIdentifier, privacy: .public)")
        let host = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let helper = host.appendingPathComponent("Contents/Helpers/FinderMenuOpener.app")
        let options = NSWorkspace.OpenConfiguration()
        options.activates = false
        options.createsNewApplicationInstance = true
        let logger = logger
        NSWorkspace.shared.open([requestURL], withApplicationAt: helper, configuration: options) { _, error in
            guard let error else { return }
            let message = error.localizedDescription
            logger.error("Open helper failed: \(message, privacy: .public)")
            Task { @MainActor in Self.showError(message) }
        }
    }

    private static func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Finder Menu"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
