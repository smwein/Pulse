// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WatchBridge",
    platforms: [.iOS(.v17), .watchOS(.v10), .macOS(.v14)],
    products: [
        .library(name: "WatchBridge", targets: ["WatchBridge"])
    ],
    dependencies: [
        .package(name: "Logging", path: "../Logging")
    ],
    targets: [
        .target(name: "WatchBridge",
                dependencies: [
                    .product(name: "Logging", package: "Logging")
                ],
                path: "Sources/WatchBridge"),
        .testTarget(name: "WatchBridgeTests",
                    dependencies: ["WatchBridge"],
                    path: "Tests/WatchBridgeTests")
    ]
)
