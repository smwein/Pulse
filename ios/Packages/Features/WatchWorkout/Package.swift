// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WatchWorkout",
    platforms: [.watchOS(.v10), .macOS(.v14)],
    products: [
        .library(name: "WatchWorkout", targets: ["WatchWorkout"])
    ],
    dependencies: [
        .package(name: "WatchBridge", path: "../../WatchBridge"),
        .package(name: "Logging", path: "../../Logging"),
        .package(name: "HealthKitClient", path: "../../HealthKitClient")
    ],
    targets: [
        .target(name: "WatchWorkout",
                dependencies: [
                    .product(name: "WatchBridge", package: "WatchBridge"),
                    .product(name: "Logging", package: "Logging"),
                    .product(name: "HealthKitClient", package: "HealthKitClient")
                ],
                path: "Sources/WatchWorkout"),
        .testTarget(name: "WatchWorkoutTests",
                    dependencies: ["WatchWorkout"],
                    path: "Tests/WatchWorkoutTests")
    ]
)
