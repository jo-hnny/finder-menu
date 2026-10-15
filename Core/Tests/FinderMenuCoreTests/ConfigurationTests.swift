import Foundation
import Testing
@testable import FinderMenuCore

@Suite struct ConfigurationTests {
    @Test func migratesVersion1Configuration() throws {
        let legacy = Data("""
        {"version":1,"entries":[
          {"id":"93EDCF61-7992-4E72-8CBA-694D7E804084","kind":"application","title":"用 Otty 打开","enabled":true,
           "scope":"folders","bundleIdentifier":"io.appmakes.otty","applicationPath":"/Applications/Otty.app"},
          {"id":"00000000-0000-0000-0000-000000000001","kind":"copyPaths","title":"复制路径","enabled":false,"scope":"both"}
        ]}
        """.utf8)
        let configuration = try MenuConfiguration.decode(legacy)
        #expect(configuration.items == [
            MenuItem(id: UUID(uuidString: "93EDCF61-7992-4E72-8CBA-694D7E804084")!, title: "用 Otty 打开", scope: .folders,
                     action: .open(application: ApplicationRef(bundleIdentifier: "io.appmakes.otty", path: "/Applications/Otty.app"))),
            MenuItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, title: "复制路径", isEnabled: false, action: .copyPaths)
        ])
    }

    @Test func roundTripPreservesOrderAndState() throws {
        var configuration = MenuConfiguration.defaults
        configuration.items.reverse()
        configuration.items[0].isEnabled = false
        configuration.items[1].scope = .files
        #expect(try MenuConfiguration.decode(configuration.encoded()) == configuration)
    }

    @Test func refusesNewerVersionsInsteadOfOverwriting() {
        #expect(throws: ConfigurationError.unsupportedVersion(3)) {
            try MenuConfiguration.decode(Data(#"{"version":3,"items":[]}"#.utf8))
        }
    }

    @Test(arguments: [
        #"{"items":[]}"#,
        #"{"version":2,"items":[{"id":"x"}]}"#,
        #"{"version":1,"entries":[{"id":"00000000-0000-0000-0000-000000000009","kind":"application","title":"A","enabled":true,"scope":"both"}]}"#
    ])
    func rejectsMalformedData(json: String) {
        #expect(throws: ConfigurationError.invalid) { try MenuConfiguration.decode(Data(json.utf8)) }
    }

    @Test func rejectsDuplicateIDsAndBlankTitles() {
        let item = MenuConfiguration.defaults.items[0]
        #expect(throws: ConfigurationError.invalid) { try MenuConfiguration(items: [item, item]).encoded() }
        var blank = item
        blank.title = "  \n"
        #expect(throws: ConfigurationError.invalid) { try MenuConfiguration(items: [blank]).encoded() }
    }
}

@Suite struct EditingTests {
    private func configuration(_ titles: String...) -> MenuConfiguration {
        MenuConfiguration(items: titles.map { MenuItem(title: $0, action: .copyPaths) })
    }

    @Test(arguments: [
        (IndexSet([0]), 3, ["B", "C", "A", "D"]),
        (IndexSet([3]), 0, ["D", "A", "B", "C"]),
        (IndexSet([0, 2]), 4, ["B", "D", "A", "C"]),
        (IndexSet([1]), 1, ["A", "B", "C", "D"])
    ])
    func moveMatchesListSemantics(source: IndexSet, destination: Int, expected: [String]) {
        var subject = configuration("A", "B", "C", "D")
        subject.move(fromOffsets: source, toOffset: destination)
        #expect(subject.items.map(\.title) == expected)
    }

    @Test func builtInItemsCannotBeRemoved() {
        var subject = MenuConfiguration.defaults
        for item in subject.items { subject.remove(id: item.id) }
        #expect(subject.items.map(\.action) == [.copyPaths])
    }

    @Test func addingSkipsDuplicatesAndOwnBundles() {
        var subject = MenuConfiguration.defaults
        let added = subject.addApplications([
            ApplicationCandidate(bundleIdentifier: "com.microsoft.VSCode", displayName: "Code", path: "/A/Code.app"),
            ApplicationCandidate(bundleIdentifier: "com.apple.Preview", displayName: "预览", path: "/A/Preview.app"),
            ApplicationCandidate(bundleIdentifier: "com.apple.Preview", displayName: "预览", path: "/B/Preview.app"),
            ApplicationCandidate(bundleIdentifier: "dev.jojo.FinderMenu.Opener", displayName: "Opener", path: "/A/O.app")
        ])
        #expect(added == 1)
        #expect(subject.items.last?.title.contains("预览") == true)
        #expect(subject.items.last?.action.application == ApplicationRef(bundleIdentifier: "com.apple.Preview", path: "/A/Preview.app"))
    }

    @Test func displayNameDropsOnlyTrailingAppSuffix() {
        #expect(ApplicationCandidate.displayName(fromFileName: "My.app Builder.app") == "My.app Builder")
        #expect(ApplicationCandidate.displayName(fromFileName: "Visual Studio Code") == "Visual Studio Code")
    }
}
