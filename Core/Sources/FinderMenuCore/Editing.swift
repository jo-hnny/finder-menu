import Foundation

public struct ApplicationCandidate: Equatable, Sendable {
    public var bundleIdentifier: String
    public var displayName: String
    public var path: String

    public init(bundleIdentifier: String, displayName: String, path: String) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.path = path
    }

    /// Finder shows "Visual Studio Code.app" when extensions are visible; only the suffix is dropped.
    public static func displayName(fromFileName name: String) -> String {
        name.hasSuffix(".app") ? String(name.dropLast(4)) : name
    }
}

extension MenuConfiguration {
    public mutating func update(_ item: MenuItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index] = item
    }

    /// Same semantics as `Array.move(fromOffsets:toOffset:)`, which SwiftUI's `onMove` reports.
    public mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let moving = source.map { items[$0] }
        let insertion = destination - source.count(in: 0..<destination)
        for index in source.reversed() { items.remove(at: index) }
        items.insert(contentsOf: moving, at: insertion)
    }

    public mutating func remove(id: UUID) {
        items.removeAll { $0.id == id && $0.isRemovable }
    }

    /// Appends apps not already present (by bundle ID) and returns how many were added.
    @discardableResult
    public mutating func addApplications(_ candidates: [ApplicationCandidate]) -> Int {
        var added = 0
        for candidate in candidates where !candidate.bundleIdentifier.isEmpty {
            guard !candidate.bundleIdentifier.hasPrefix(FinderMenuIdentity.bundleIdentifier),
                  !items.contains(where: { $0.action.application?.bundleIdentifier == candidate.bundleIdentifier }) else {
                continue
            }
            let title = String(localized: "用 \(candidate.displayName) 打开", bundle: .module)
            items.append(MenuItem(title: title,
                                  action: .open(application: ApplicationRef(bundleIdentifier: candidate.bundleIdentifier,
                                                                            path: candidate.path))))
            added += 1
        }
        return added
    }
}
