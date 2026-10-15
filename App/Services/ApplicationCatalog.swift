import AppKit
import FinderMenuCore
import Observation

/// Resolves app locations, names and icons once per app instead of on every view update.
@MainActor @Observable
final class ApplicationCatalog {
    struct Entry {
        let url: URL?
        let name: String?
        let icon: NSImage?
    }

    @ObservationIgnored private var cache: [ApplicationRef: Entry] = [:]
    private var generation = 0

    func entry(for application: ApplicationRef) -> Entry {
        _ = generation
        if let entry = cache[application] { return entry }
        let url = ApplicationResolver.url(for: application)
        let entry = Entry(url: url,
                          name: url.flatMap(ApplicationResolver.candidate(at:))?.displayName,
                          icon: url.map { NSWorkspace.shared.icon(forFile: $0.path) })
        cache[application] = entry
        return entry
    }

    /// Apps may have been installed, moved or deleted while the window was in the background.
    func invalidate() {
        cache.removeAll()
        generation += 1
    }
}
