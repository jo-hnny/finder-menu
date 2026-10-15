// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FinderMenuCore",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14)],
    products: [.library(name: "FinderMenuCore", targets: ["FinderMenuCore"])],
    targets: [
        .target(name: "FinderMenuCore", resources: [.process("Resources")]),
        .testTarget(name: "FinderMenuCoreTests", dependencies: ["FinderMenuCore"])
    ]
)
