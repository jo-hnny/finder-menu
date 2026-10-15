import FinderMenuCore
import Foundation
import Observation

@MainActor @Observable
final class MenuStore {
    private(set) var configuration = MenuConfiguration(items: [])
    /// Editing stays off when the saved configuration cannot be read, so it is never overwritten.
    private(set) var isLoaded = false
    private(set) var message: String?
    var selectedID: UUID?

    private let preferences = PreferencesStore.shared

    init() {
        do {
            configuration = try preferences.loadConfiguration()
            isLoaded = true
        } catch { message = error.localizedDescription }
        do { try preferences.ensureSigningKey() } catch { message = message ?? error.localizedDescription }
    }

    var items: [MenuItem] { configuration.items }
    var selectedItem: MenuItem? { selectedID.flatMap(configuration.item(id:)) }

    func update(_ item: MenuItem) { mutate { $0.update(item) } }

    /// Empty titles are ignored and the previous title stays in place.
    func rename(id: UUID, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var item = configuration.item(id: id) else { return }
        item.title = trimmed
        update(item)
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        mutate { $0.move(fromOffsets: source, toOffset: destination) }
    }

    func move(id: UUID, to targetID: UUID) {
        guard id != targetID,
              let source = items.firstIndex(where: { $0.id == id }),
              let target = items.firstIndex(where: { $0.id == targetID }) else { return }
        move(fromOffsets: [source], toOffset: source < target ? target + 1 : target)
    }

    func canMoveSelected(by offset: Int) -> Bool {
        guard let index = items.firstIndex(where: { $0.id == selectedID }) else { return false }
        return items.indices.contains(index + offset)
    }

    func moveSelected(by offset: Int) {
        guard canMoveSelected(by: offset),
              let index = items.firstIndex(where: { $0.id == selectedID }) else { return }
        move(id: items[index].id, to: items[index + offset].id)
    }

    func remove(id: UUID) {
        mutate { $0.remove(id: id) }
        if selectedID == id, configuration.item(id: id) == nil { selectedID = nil }
    }

    func addApplications(at urls: [URL]) {
        let candidates = urls.compactMap(ApplicationResolver.candidate(at:))
        mutate { $0.addApplications(candidates) }
        let skipped = urls.count - candidates.count
        if skipped > 0 { message = String(localized: "已跳过 \(skipped) 个无效的应用。") }
    }

    /// Saves first and only then publishes, so a failed save keeps the last saved list on screen.
    private func mutate(_ change: (inout MenuConfiguration) -> Void) {
        guard isLoaded else { return }
        var next = configuration
        change(&next)
        guard next != configuration else { return }
        do {
            try preferences.save(next)
            configuration = next
            message = nil
        } catch { message = error.localizedDescription }
    }
}
