import SwiftUI

@main
struct FinderMenuApp: App {
    var body: some Scene {
        Window("Finder Menu", id: "main") {
            ContentView()
        }
        .defaultSize(width: 960, height: 640)
        .windowResizability(.contentMinSize)
    }
}
