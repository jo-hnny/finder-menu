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

    @MainActor public static func menuIcon(at url: URL) -> NSImage? {
        rasterizedMenuIcon(NSWorkspace.shared.icon(forFile: url.path))
    }

    /// Setting NSImage.size alone retains every full-resolution representation in its XPC archive.
    /// Send Finder one 32-pixel bitmap, displayed at 16 points, instead of the entire app icon.
    @MainActor static func rasterizedMenuIcon(_ source: NSImage) -> NSImage? {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let bitmapContext = CGContext(data: nil, width: 32, height: 32, bitsPerComponent: 8,
                                            bytesPerRow: 0, space: colorSpace,
                                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let context = NSGraphicsContext(cgContext: bitmapContext, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        source.draw(in: NSRect(x: 0, y: 0, width: 32, height: 32), from: .zero,
                    operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()

        guard let image = bitmapContext.makeImage() else { return nil }
        let bitmap = NSBitmapImageRep(cgImage: image)
        let size = NSSize(width: 16, height: 16)
        bitmap.size = size
        let icon = NSImage(size: size)
        icon.addRepresentation(bitmap)
        return icon
    }
}
