import CryptoKit
import Foundation
import Testing
@testable import FinderMenuCore

@Suite struct OpenRequestTests {
    let key = SymmetricKey(size: .bits256)
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    var request: OpenRequest {
        OpenRequest(itemID: UUID(), paths: ["/Users/me/中文 空格/a&b=c?.txt", "/tmp"], issuedAt: now)
    }

    @Test func acceptsSignedRequest() throws {
        let original = request
        #expect(try OpenRequest.verified(from: original.signedURL(key: key), key: key, now: now.addingTimeInterval(1)) == original)
    }

    @Test func rejectsWrongKeyAndTamperedPayload() throws {
        let url = try request.signedURL(key: key)
        #expect(throws: OpenRequest.Failure.badSignature) {
            try OpenRequest.verified(from: url, key: SymmetricKey(size: .bits256), now: now)
        }
        let forged = OpenRequest(itemID: request.itemID, paths: ["/etc/hosts"], issuedAt: now)
        var components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let forgedPayload = try #require(URLComponents(url: forged.signedURL(key: SymmetricKey(size: .bits256)),
                                                       resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "p" })
        components.queryItems = [forgedPayload] + (components.queryItems ?? []).filter { $0.name == "s" }
        #expect(throws: OpenRequest.Failure.badSignature) {
            try OpenRequest.verified(from: try #require(components.url), key: key, now: now)
        }
    }

    @Test func rejectsUnsignedLegacyRequest() throws {
        let legacy = try #require(URL(string: "findermenu-open://open/00000000-0000-0000-0000-000000000002?paths=WyIvZXRjL2hvc3RzIl0="))
        #expect(throws: OpenRequest.Failure.malformed) { try OpenRequest.verified(from: legacy, key: key, now: now) }
    }

    @Test(arguments: [OpenRequest.maxAge + 1, -10])
    func rejectsStaleOrFutureRequests(offset: TimeInterval) throws {
        let url = try request.signedURL(key: key)
        #expect(throws: OpenRequest.Failure.expired) {
            try OpenRequest.verified(from: url, key: key, now: now.addingTimeInterval(offset))
        }
    }

    @Test(arguments: [[String](), ["relative/path"], ["/ok", "/bad\0"]])
    func rejectsInvalidPathsEvenWhenSigned(paths: [String]) throws {
        let url = try OpenRequest(itemID: UUID(), paths: paths, issuedAt: now).signedURL(key: key)
        #expect(throws: OpenRequest.Failure.invalidPaths) { try OpenRequest.verified(from: url, key: key, now: now) }
    }
}
