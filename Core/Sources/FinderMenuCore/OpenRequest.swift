import CryptoKit
import Foundation

/// An "open with" request handed from the Finder extension to the opener helper.
/// The helper is unsandboxed, so it only acts on requests signed with the per-install key
/// that sandboxed apps and web content cannot read.
public struct OpenRequest: Codable, Equatable, Sendable {
    public var itemID: UUID
    public var paths: [String]
    public var issuedAt: Date

    public init(itemID: UUID, paths: [String], issuedAt: Date = Date()) {
        self.itemID = itemID
        self.paths = paths
        self.issuedAt = issuedAt
    }

    public static let maxAge: TimeInterval = 30
    /// Tolerated clock skew for requests stamped slightly in the future.
    static let futureSkew: TimeInterval = 5
    static let scheme = "findermenu-open"

    public enum Failure: LocalizedError, Equatable {
        case malformed, badSignature, expired, invalidPaths

        public var errorDescription: String? {
            switch self {
            case .malformed, .badSignature: return String(localized: "打开请求无效，已拒绝。", bundle: .module)
            case .expired: return String(localized: "打开请求已过期，请在 Finder 中重新操作。", bundle: .module)
            case .invalidPaths: return String(localized: "所选项目的路径无效。", bundle: .module)
            }
        }
    }

    public func signedURL(key: SymmetricKey) throws -> URL {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let payload = try encoder.encode(self)
        let signature = Data(HMAC<SHA256>.authenticationCode(for: payload, using: key))
        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = "open"
        components.queryItems = [
            URLQueryItem(name: "p", value: payload.base64URLEncodedString()),
            URLQueryItem(name: "s", value: signature.base64URLEncodedString())
        ]
        guard let url = components.url else { throw Failure.malformed }
        return url
    }

    /// Verifies the signature over the exact payload bytes before decoding anything else.
    public static func verified(from url: URL, key: SymmetricKey, now: Date = Date()) throws -> OpenRequest {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == scheme, components.host == "open",
              let items = components.queryItems, items.count == 2,
              let payload = items.first(where: { $0.name == "p" })?.value.flatMap(Data.init(base64URLEncoded:)),
              let signature = items.first(where: { $0.name == "s" })?.value.flatMap(Data.init(base64URLEncoded:)) else {
            throw Failure.malformed
        }
        guard HMAC<SHA256>.isValidAuthenticationCode(signature, authenticating: payload, using: key) else {
            throw Failure.badSignature
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let request = try? decoder.decode(OpenRequest.self, from: payload) else { throw Failure.malformed }
        let age = now.timeIntervalSince(request.issuedAt)
        guard age <= maxAge, age >= -futureSkew else { throw Failure.expired }
        guard !request.paths.isEmpty,
              request.paths.allSatisfy({ $0.hasPrefix("/") && !$0.contains("\0") }) else {
            throw Failure.invalidPaths
        }
        return request
    }
}

extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(base64URLEncoded string: String) {
        var base64 = string.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        self.init(base64Encoded: base64)
    }
}
