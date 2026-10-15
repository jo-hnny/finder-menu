import Foundation
import Testing
@testable import FinderMenuCore

@Suite struct SelectionTests {
    let root: URL
    let file: URL
    let folder: URL
    let package: URL
    let folderLink: URL

    init() throws {
        let manager = FileManager.default
        root = manager.temporaryDirectory.appendingPathComponent("FinderMenuTests-\(UUID().uuidString)")
        file = root.appendingPathComponent("中文 空格 #?.txt")
        folder = root.appendingPathComponent("目录 空格")
        package = root.appendingPathComponent("Sample.app")
        folderLink = root.appendingPathComponent("link")
        try manager.createDirectory(at: folder, withIntermediateDirectories: true)
        try manager.createDirectory(at: package.appendingPathComponent("Contents"), withIntermediateDirectories: true)
        try Data("fixture".utf8).write(to: file)
        try manager.createSymbolicLink(at: folderLink, withDestinationURL: folder)
    }

    @Test func classifiesSelections() {
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(SelectionKind(classifying: [file]) == .files)
        #expect(SelectionKind(classifying: [folder, folderLink]) == .folders)
        #expect(SelectionKind(classifying: [file, folder]) == .mixed)
        #expect(SelectionKind(classifying: [package]) == .files)
        #expect(SelectionKind(classifying: []) == nil)
    }

    @Test func visibleItemsRespectScopeAndEnabledState() {
        defer { try? FileManager.default.removeItem(at: root) }
        let items = [
            MenuItem(title: "all", action: .copyPaths),
            MenuItem(title: "files", scope: .files, action: .copyPaths),
            MenuItem(title: "folders", scope: .folders, action: .copyPaths),
            MenuItem(title: "off", isEnabled: false, action: .copyPaths)
        ]
        let configuration = MenuConfiguration(items: items)
        #expect(configuration.visibleItems(for: .files).map(\.title) == ["all", "files"])
        #expect(configuration.visibleItems(for: .folders).map(\.title) == ["all", "folders"])
        #expect(configuration.visibleItems(for: .mixed).map(\.title) == ["all"])
    }
}
