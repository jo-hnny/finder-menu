import AppKit
import OSLog

// LaunchServices starts a fresh, short-lived agent for each open action.
// It never launches the configuration app, runs a shell, or registers at login.
final class OpenerDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "dev.jojo.FinderMenu", category: "Opener")

    private var receivedRequest = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Opening this internal helper directly should not leave a resident process.
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [self] in
            if !receivedRequest { NSApp.terminate(nil) }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        receivedRequest = true
        do {
            guard urls.count == 1,
                  let request = URLComponents(url: urls[0], resolvingAgainstBaseURL: false),
                  request.scheme == "findermenu-open", request.host == "open",
                  let id = UUID(uuidString: String(request.path.dropFirst())),
                  let payload = request.queryItems?.first(where: { $0.name == "paths" })?.value,
                  let data = Data(base64Encoded: payload) else {
                throw ConfigurationError.invalid
            }
            let paths = try JSONDecoder().decode([String].self, from: data)
            guard !paths.isEmpty, paths.allSatisfy({ $0.hasPrefix("/") && !$0.contains("\0") }),
                  let entry = try ConfigurationRepository().load().entries.first(where: { $0.id == id }),
                  entry.kind == .application, entry.enabled,
                  let application = entry.applicationURL else {
                throw ConfigurationError.invalid
            }
            let urls = paths.map { URL(fileURLWithPath: $0) }
            guard entry.applies(to: urls) else { throw ConfigurationError.invalid }
            NSWorkspace.shared.open(urls, withApplicationAt: application, configuration: .init()) { [self] _, error in
                DispatchQueue.main.async {
                    if let error {
                        self.fail(error)
                    } else {
                        self.logger.notice("Open succeeded: app=\(entry.bundleIdentifier ?? "", privacy: .public), count=\(urls.count)")
                        NSApp.terminate(nil)
                    }
                }
            }
        } catch { fail(error) }
    }

    private func fail(_ error: Error) {
        logger.error("Open failed: \(error.localizedDescription, privacy: .public)")
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "无法使用所选应用打开"
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
