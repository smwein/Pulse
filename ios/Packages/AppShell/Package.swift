// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AppShell",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "AppShell", targets: ["AppShell"])],
    dependencies: [
        .package(path: "../DesignSystem"),
        .package(path: "../Repositories"),
    ],
    targets: [
        .target(name: "AppShell", dependencies: ["DesignSystem", "Repositories"]),
        .testTarget(name: "AppShellTests", dependencies: ["AppShell"]),
    ]
)
