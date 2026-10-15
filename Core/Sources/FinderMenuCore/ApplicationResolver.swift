import AppKit

public enum ApplicationResolver {
    /// Prefers the recorded path while it still holds the same bundle, then asks LaunchServices.
    public static func url(for application: ApplicationRef) -> URL? {
        if let path = application.path {
            let url = URL(fileURLWithPath: path)
            if Bundle(url: url)?.bundleIdentifier == application.bundleIdentifier { return url }
        }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: application.bundleIdentifier)
    }

    /// `nil` unless the URL is an application bundle with a bundle identifier.
    public static func candidate(at url: URL) -> ApplicationCandidate? {
        guard let bundle = Bundle(url: url), let identifier = bundle.bundleIdentifier,
              bundle.object(forInfoDictionaryKey: "CFBundlePackageType") as? String == "APPL" else {
            return nil
        }
        let name = ApplicationCandidate.displayName(fromFileName: FileManager.default.displayName(atPath: url.path))
        return ApplicationCandidate(bundleIdentifier: identifier, displayName: name, path: url.path)
    }
}
