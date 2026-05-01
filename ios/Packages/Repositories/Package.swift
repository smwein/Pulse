// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Repositories",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "Repositories", targets: ["Repositories"])],
    dependencies: [
        .package(path: "../CoreModels"),
        .package(path: "../Persistence"),
        .package(path: "../Networking"),
        .package(path: "../HealthKitClient"),
        .package(name: "Logging", path: "../Logging"),
        .package(name: "WatchBridge", path: "../WatchBridge"),
    ],
    targets: [
        .target(
            name: "Repositories",
            dependencies: ["CoreModels", "Persistence", "Networking", "HealthKitClient",
                           .product(name: "Logging", package: "Logging"),
                           .product(name: "WatchBridge", package: "WatchBridge")]
        ),
        .testTarget(
            name: "RepositoriesTests",
            dependencies: ["Repositories"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
