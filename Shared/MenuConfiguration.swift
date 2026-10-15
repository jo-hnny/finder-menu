import AppKit

struct MenuEntry: Codable, Identifiable, Equatable {
    enum Kind: String, Codable { case copyPaths, application }
    enum Scope: String, Codable, CaseIterable {
        case both, files, folders
        var title: String {
            switch self {
            case .both: return "文件与文件夹"
            case .files: return "仅文件"
            case .folders: return "仅文件夹"
            }
        }
    }
    var id: UUID
    var kind: Kind
    var title: String
    var enabled: Bool
    var scope: Scope
    var bundleIdentifier: String?
    var applicationPath: String?

    static let defaults: [MenuEntry] = [
        MenuEntry(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, kind: .copyPaths,
                  title: "复制路径", enabled: true, scope: .both),
        MenuEntry(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, kind: .application,
                  title: "用 Visual Studio Code 打开", enabled: true, scope: .both,
                  bundleIdentifier: "com.microsoft.VSCode")
    ]

    var applicationURL: URL? {
        if let path = applicationPath {
            let url = URL(fileURLWithPath: path)
            if Bundle(url: url)?.bundleIdentifier == bundleIdentifier { return url }
        }
        return bundleIdentifier.flatMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
    }

    func applies(to urls: [URL]) -> Bool {
        enabled && !urls.isEmpty && urls.allSatisfy { url in
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? url.hasDirectoryPath
            return scope == .both || (scope == .folders ? isDirectory : !isDirectory)
        }
    }
}

struct MenuConfiguration: Codable, Equatable {
    var version = 1
    var entries: [MenuEntry]

    func validate() throws {
        guard version == 1, Set(entries.map(\.id)).count == entries.count,
              entries.allSatisfy({ !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                  ($0.kind == .copyPaths || !($0.bundleIdentifier ?? "").isEmpty) }) else {
            throw ConfigurationError.invalid
        }
    }
}

enum ConfigurationError: LocalizedError {
    case invalid, saveFailed
    var errorDescription: String? {
        switch self {
        case .invalid: return "菜单配置无法读取，原配置已保留。"
        case .saveFailed: return "无法保存菜单配置，请重试。"
        }
    }
}

// A narrowly entitled shared preference domain works with this local ad-hoc build.
// No access to other apps' preferences or user documents is granted.
struct ConfigurationRepository {
    static let domain = "dev.jojo.FinderMenu.Configuration"
    static let key = "menuConfiguration"

    func load() throws -> MenuConfiguration {
        CFPreferencesAppSynchronize(Self.domain as CFString)
        guard let value = CFPreferencesCopyAppValue(Self.key as CFString, Self.domain as CFString) else {
            return MenuConfiguration(entries: MenuEntry.defaults)
        }
        guard let data = value as? Data else { throw ConfigurationError.invalid }
        let result = try JSONDecoder().decode(MenuConfiguration.self, from: data)
        try result.validate()
        return result
    }

    func save(_ configuration: MenuConfiguration) throws {
        try configuration.validate()
        let data = try JSONEncoder().encode(configuration)
        CFPreferencesSetAppValue(Self.key as CFString, data as CFData, Self.domain as CFString)
        guard CFPreferencesAppSynchronize(Self.domain as CFString) else { throw ConfigurationError.saveFailed }
    }
}
