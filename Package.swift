// swift-tools-version: 6.0
import PackageDescription

// Exercise the app's window code without launching or registering Finder extensions.
let package = Package(
    name: "FinderMenuWindowing",
    platforms: [.macOS(.v14)],
    dependencies: [.package(path: "Core")],
    targets: [
        .target(
            name: "FinderMenuWindowing",
            dependencies: [.product(name: "FinderMenuCore", package: "Core")],
            path: "App/Views",
            exclude: ["GlassSurface.swift", "InspectorReveal.swift", "ItemInspector.swift",
                      "MenuPreview.swift", "MenuRow.swift", "StatusBar.swift", "WorkspaceBackdrop.swift"],
            sources: ["InspectorWindowLayout.swift", "InspectorWindowResize.swift"]
        ),
        .testTarget(name: "FinderMenuWindowingTests", dependencies: ["FinderMenuWindowing"])
    ]
)
