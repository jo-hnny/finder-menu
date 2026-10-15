import CryptoKit
import Foundation

/// Shared preference domain read by the app (read-write), the extension (read-only) and the helper.
/// A narrowly entitled shared preference works with ad-hoc signing; App Groups need a Team ID.
public struct PreferencesStore: Sendable {
    public static let shared = PreferencesStore(domain: "dev.jojo.FinderMenu.Configuration")

    private static let configurationKey = "menuConfiguration"
    private static let signingKeyKey = "requestSigningKey"

    let domain: String

    init(domain: String) { self.domain = domain }

    public func loadConfiguration() throws -> MenuConfiguration {
        guard let value = copyValue(Self.configurationKey) else { return .defaults }
        guard let data = value as? Data else { throw ConfigurationError.invalid }
        return try MenuConfiguration.decode(data)
    }

    public func save(_ configuration: MenuConfiguration) throws {
        try setValue(configuration.encoded(), for: Self.configurationKey)
    }

    /// `nil` until the configuration app has launched once since installing this version.
    public func signingKey() -> SymmetricKey? {
        guard let data = copyValue(Self.signingKeyKey) as? Data, data.count == 32 else { return nil }
        return SymmetricKey(data: data)
    }

    /// Called by the configuration app, the only writer with read-write access.
    public func ensureSigningKey() throws {
        guard signingKey() == nil else { return }
        try setValue(SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }, for: Self.signingKeyKey)
    }

    private func copyValue(_ key: String) -> CFPropertyList? {
        CFPreferencesAppSynchronize(domain as CFString)
        return CFPreferencesCopyAppValue(key as CFString, domain as CFString)
    }

    private func setValue(_ data: Data, for key: String) throws {
        CFPreferencesSetAppValue(key as CFString, data as CFData, domain as CFString)
        guard CFPreferencesAppSynchronize(domain as CFString) else { throw ConfigurationError.saveFailed }
    }
}
