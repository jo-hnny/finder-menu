import Foundation

public enum SelectionKind: Sendable {
    case files, folders, mixed

    /// Stats each item at most once and stops as soon as the selection is known to be mixed.
    /// Packages (`.app`, `.rtfd`) count as files, matching Finder; symlinks follow their target.
    public init?(classifying urls: [URL]) {
        var hasFile = false, hasFolder = false
        for url in urls {
            if Self.isFolder(url) { hasFolder = true } else { hasFile = true }
            if hasFile && hasFolder { self = .mixed; return }
        }
        if hasFolder { self = .folders } else if hasFile { self = .files } else { return nil }
    }

    private static func isFolder(_ url: URL) -> Bool {
        let resolved = url.resolvingSymlinksInPath()
        guard let values = try? resolved.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey]),
              let isDirectory = values.isDirectory else {
            return url.hasDirectoryPath
        }
        return isDirectory && values.isPackage != true
    }
}

extension MenuScope {
    public func accepts(_ kind: SelectionKind) -> Bool {
        switch (self, kind) {
        case (.all, _), (.files, .files), (.folders, .folders): return true
        default: return false
        }
    }
}

extension MenuConfiguration {
    public func visibleItems(for kind: SelectionKind) -> [MenuItem] {
        items.filter { $0.isEnabled && $0.scope.accepts(kind) }
    }
}
