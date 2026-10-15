import AppKit
import FinderMenuCore
import OSLog

enum OpenerError: LocalizedError {
    case itemUnavailable, applicationMissing

    var errorDescription: String? {
        switch self {
        case .itemUnavailable: return String(localized: "这个菜单项已被禁用、移除，或不适用于所选项目。")
        case .applicationMissing: return String(localized: "找不到这个应用，请在 Finder Menu 中重新添加。")
        }
    }
}

// LaunchServices starts a fresh, short-lived agent for each open action.
// It never launches the configuration app, runs a shell, or registers at login.
@MainActor
final class OpenerDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: FinderMenuIdentity.logSubsystem, category: "Opener")
    private var receivedRequest = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Opening this internal helper directly should not leave a resident process.
        Task {
            try? await Task.sleep(for: .seconds(10))
            if !receivedRequest { NSApp.terminate(nil) }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        receivedRequest = true
        let preferences = PreferencesStore.shared
        let request: OpenRequest
        do {
            guard urls.count == 1, let key = preferences.signingKey() else { throw OpenRequest.Failure.malformed }
            request = try OpenRequest.verified(from: urls[0], key: key)
        } catch {
            // Unauthenticated callers get no UI: log and exit so they cannot drive alerts either.
            logger.error("Rejected open request: \(error.localizedDescription, privacy: .public)")
            NSApp.terminate(nil)
            return
        }
        do {
            let targets = request.paths.map { URL(fileURLWithPath: $0) }
            guard let item = try preferences.loadConfiguration().item(id: request.itemID), item.isEnabled,
                  let reference = item.action.application,
                  let selection = SelectionKind(classifying: targets), item.scope.accepts(selection) else {
                throw OpenerError.itemUnavailable
            }
            guard let applicationURL = ApplicationResolver.url(for: reference) else { throw OpenerError.applicationMissing }
            NSWorkspace.shared.open(targets, withApplicationAt: applicationURL, configuration: .init()) { _, error in
                Task { @MainActor in
                    if let error {
                        self.fail(error)
                    } else {
                        self.logger.notice("Open succeeded: app=\(reference.bundleIdentifier, privacy: .public), count=\(targets.count)")
                        NSApp.terminate(nil)
                    }
                }
            }
        } catch { fail(error) }
    }

    private func fail(_ error: Error) {
        logger.error("Open failed: \(error.localizedDescription, privacy: .public)")
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = String(localized: "无法使用所选应用打开")
        alert.informativeText = error.localizedDescription
        alert.runModal()
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = OpenerDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
