import Foundation

public enum FinderMenuIdentity {
    public static let bundleIdentifier = "dev.jojo.FinderMenu"
    public static let logSubsystem = "dev.jojo.FinderMenu"
}

public enum MenuScope: String, Codable, CaseIterable, Sendable {
    case all, files, folders

    public var title: String {
        switch self {
        case .all: return String(localized: "文件与文件夹", bundle: .module)
        case .files: return String(localized: "仅文件", bundle: .module)
        case .folders: return String(localized: "仅文件夹", bundle: .module)
        }
    }
}

public struct ApplicationRef: Codable, Hashable, Sendable {
    public var bundleIdentifier: String
    /// Last known location; the bundle identifier stays authoritative when the app moves.
    public var path: String?

    public init(bundleIdentifier: String, path: String? = nil) {
        self.bundleIdentifier = bundleIdentifier
        self.path = path
    }
}

public enum MenuAction: Codable, Equatable, Sendable {
    case copyPaths
    case open(application: ApplicationRef)

    public var application: ApplicationRef? {
        if case .open(let application) = self { return application }
        return nil
    }
}

public struct MenuItem: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var isEnabled: Bool
    public var scope: MenuScope
    public var action: MenuAction

    public init(id: UUID = UUID(), title: String, isEnabled: Bool = true, scope: MenuScope = .all, action: MenuAction) {
        self.id = id
        self.title = title
        self.isEnabled = isEnabled
        self.scope = scope
        self.action = action
    }

    /// Built-in items can be disabled but not removed.
    public var isRemovable: Bool { action.application != nil }
}

public enum ConfigurationError: LocalizedError, Equatable {
    case invalid, unsupportedVersion(Int), saveFailed

    public var errorDescription: String? {
        switch self {
        case .invalid: return String(localized: "菜单配置无法读取，原配置已保留。", bundle: .module)
        case .unsupportedVersion:
            return String(localized: "菜单配置来自更新版本的 Finder Menu，请升级后再修改。", bundle: .module)
        case .saveFailed: return String(localized: "无法保存菜单配置，请重试。", bundle: .module)
        }
    }
}

public struct MenuConfiguration: Equatable, Sendable {
    public static let currentVersion = 2
    public var items: [MenuItem]

    public init(items: [MenuItem]) { self.items = items }

    public static let defaults = MenuConfiguration(items: [
        MenuItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, title: "复制路径", action: .copyPaths),
        MenuItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, title: "用 Visual Studio Code 打开",
                 action: .open(application: ApplicationRef(bundleIdentifier: "com.microsoft.VSCode")))
    ])

    public func item(id: UUID) -> MenuItem? { items.first { $0.id == id } }

    public func validate() throws {
        guard Set(items.map(\.id)).count == items.count,
              items.allSatisfy({ !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                  $0.action.application?.bundleIdentifier.isEmpty != true }) else {
            throw ConfigurationError.invalid
        }
    }
}

// MARK: - Persistence format

extension MenuConfiguration {
    private struct Envelope: Codable {
        var version: Int
        var items: [MenuItem]
    }

    private struct VersionProbe: Decodable { var version: Int }

    /// Version 1 (0.1.x) stored a flat `kind` plus optional application fields.
    private struct LegacyV1: Decodable {
        struct Entry: Decodable {
            enum Kind: String, Decodable { case copyPaths, application }
            enum Scope: String, Decodable { case both, files, folders }
            var id: UUID
            var kind: Kind
            var title: String
            var enabled: Bool
            var scope: Scope
            var bundleIdentifier: String?
            var applicationPath: String?
        }
        var entries: [Entry]

        func migrated() throws -> [MenuItem] {
            try entries.map { entry in
                let action: MenuAction
                switch entry.kind {
                case .copyPaths: action = .copyPaths
                case .application:
                    guard let identifier = entry.bundleIdentifier else { throw ConfigurationError.invalid }
                    action = .open(application: ApplicationRef(bundleIdentifier: identifier, path: entry.applicationPath))
                }
                let scope: MenuScope = switch entry.scope {
                case .both: .all
                case .files: .files
                case .folders: .folders
                }
                return MenuItem(id: entry.id, title: entry.title, isEnabled: entry.enabled, scope: scope, action: action)
            }
        }
    }

    public static func decode(_ data: Data) throws -> MenuConfiguration {
        let decoder = JSONDecoder()
        guard let version = try? decoder.decode(VersionProbe.self, from: data).version else {
            throw ConfigurationError.invalid
        }
        let configuration: MenuConfiguration
        do {
            switch version {
            case 1: configuration = MenuConfiguration(items: try decoder.decode(LegacyV1.self, from: data).migrated())
            case currentVersion: configuration = MenuConfiguration(items: try decoder.decode(Envelope.self, from: data).items)
            default: throw ConfigurationError.unsupportedVersion(version)
            }
        } catch let error as ConfigurationError {
            throw error
        } catch {
            throw ConfigurationError.invalid
        }
        try configuration.validate()
        return configuration
    }

    public func encoded() throws -> Data {
        try validate()
        return try JSONEncoder().encode(Envelope(version: Self.currentVersion, items: items))
    }
}
