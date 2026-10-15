import SwiftUI

@main
struct FinderMenuApp: App {
    @StateObject private var updates = UpdateService()

    var body: some Scene {
        Window("Finder Menu", id: "main") {
            ContentView()
        }
        .defaultSize(width: 1080, height: 640)
        .windowResizability(.contentMinSize)
        .commands {
            MenuOrderCommands()
            CommandGroup(after: .appInfo) {
                Button("检查更新…") { updates.checkForUpdates() }
                    .disabled(!updates.canCheckForUpdates)
            }
        }
    }
}

private struct MenuStoreFocusedKey: FocusedValueKey {
    typealias Value = MenuStore
}

extension FocusedValues {
    var menuStore: MenuStore? {
        get { self[MenuStoreFocusedKey.self] }
        set { self[MenuStoreFocusedKey.self] = newValue }
    }
}

private struct MenuOrderCommands: Commands {
    @FocusedValue(\.menuStore) private var store

    var body: some Commands {
        CommandMenu("顺序") {
            Button("上移") { store?.moveSelected(by: -1) }
                .keyboardShortcut(.upArrow, modifiers: [.command, .option])
                .disabled(store?.canMoveSelected(by: -1) != true)
            Button("下移") { store?.moveSelected(by: 1) }
                .keyboardShortcut(.downArrow, modifiers: [.command, .option])
                .disabled(store?.canMoveSelected(by: 1) != true)
        }
    }
}
