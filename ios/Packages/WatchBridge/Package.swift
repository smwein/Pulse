// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WatchBridge",
    platforms: [.iOS(.v17), .watchOS(.v10), .macOS(.v14)],
    products: [
        .library(name: "WatchBridge", targets: ["WatchBridge"])
    ],
    dependencies: [
        .package(name: "Logging", path: "../Logging"),
        .package(name: "CoreModels", path: "../CoreModels")
    ],
    targets: [
        .target(name: "WatchBridge",
                dependencies: [
                    .product(name: "Logging", package: "Logging"),
                    .product(name: "CoreModels", package: "CoreModels")
                ],
                path: "Sources/WatchBridge"),
        .testTarget(name: "WatchBridgeTests",
                    dependencies: ["WatchBridge"],
                    path: "Tests/WatchBridgeTests")
    ]
)
