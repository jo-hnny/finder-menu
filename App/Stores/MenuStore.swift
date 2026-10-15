import AppKit
import Observation

@MainActor @Observable
final class MenuStore {
    private(set) var entries: [MenuEntry] = []
    private(set) var loaded = false
    var errorMessage: String?
    private let repository = ConfigurationRepository()

    init() {
        do {
            entries = try repository.load().entries
            loaded = true
        } catch { errorMessage = error.localizedDescription }
    }

    func update(_ entry: MenuEntry) {
        var next = entries
        guard let index = next.firstIndex(where: { $0.id == entry.id }) else { return }
        next[index] = entry
        commit(next)
    }

    func move(_ id: UUID, to target: UUID) {
        guard let from = entries.firstIndex(where: { $0.id == id }),
              let to = entries.firstIndex(where: { $0.id == target }), from != to else { return }
        var next = entries
        next.insert(next.remove(at: from), at: to)
        commit(next)
    }

    func remove(_ id: UUID) {
        commit(entries.filter { $0.id != id || $0.kind == .copyPaths })
    }

    func add(_ urls: [URL]) {
        var next = entries
        for url in urls {
            guard let bundle = Bundle(url: url), let identifier = bundle.bundleIdentifier,
                  bundle.object(forInfoDictionaryKey: "CFBundlePackageType") as? String == "APPL" else {
                errorMessage = "请选择有效的 macOS 应用（.app）。"
                return
            }
            guard identifier != "dev.jojo.FinderMenu", identifier != "dev.jojo.FinderMenu.Opener" else { continue }
            guard !next.contains(where: { $0.bundleIdentifier == identifier }) else { continue }
            let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
            next.append(MenuEntry(id: UUID(), kind: .application, title: "用 \(name) 打开", enabled: true,
                                  scope: .both, bundleIdentifier: identifier, applicationPath: url.path))
        }
        commit(next)
    }

    private func commit(_ next: [MenuEntry]) {
        guard loaded else { return }
        do {
            try repository.save(MenuConfiguration(entries: next))
            entries = next
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }
}
