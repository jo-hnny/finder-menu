import AppKit
import Testing
@testable import FinderMenuCore

@Suite @MainActor struct MenuIconTests {
    @Test func keepsRetinaPixelsAndTransparencyWithoutArchivingLargeRepresentations() throws {
        let source = NSImage(size: NSSize(width: 16, height: 16))
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        for pixels in [128, 1024] {
            let context = try #require(CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
                                                bytesPerRow: 0, space: colorSpace,
                                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
            context.fill(CGRect(x: pixels / 4, y: pixels / 4, width: pixels / 2, height: pixels / 2))
            let bitmap = NSBitmapImageRep(cgImage: try #require(context.makeImage()))
            bitmap.size = source.size
            source.addRepresentation(bitmap)
        }

        let original = try #require(source.representations.first as? NSBitmapImageRep)
        let expectedColor = try #require(original.colorAt(x: 64, y: 64)?.usingColorSpace(.sRGB))
        let icon = try #require(ApplicationResolver.rasterizedMenuIcon(source))
        let archive = try NSKeyedArchiver.archivedData(withRootObject: icon, requiringSecureCoding: true)
        #expect(archive.count < 16_384)
        let decoded = try #require(try NSKeyedUnarchiver.unarchivedObject(ofClass: NSImage.self, from: archive))
        #expect(decoded.size == NSSize(width: 16, height: 16))
        #expect(decoded.representations.count == 1)
        let bitmap = try #require(decoded.representations.first as? NSBitmapImageRep)
        #expect(bitmap.pixelsWide == 32 && bitmap.pixelsHigh == 32)
        #expect(try #require(bitmap.colorAt(x: 0, y: 0)).alphaComponent == 0)
        let center = try #require(bitmap.colorAt(x: 16, y: 16)?.usingColorSpace(.sRGB))
        #expect(expectedColor.redComponent > 0.9)
        #expect(abs(center.redComponent - expectedColor.redComponent) < 0.02)
        #expect(abs(center.greenComponent - expectedColor.greenComponent) < 0.02)
        #expect(abs(center.blueComponent - expectedColor.blueComponent) < 0.02)
        #expect(center.alphaComponent > 0.9)
        #expect(source.representations.count == 2)
    }
}
