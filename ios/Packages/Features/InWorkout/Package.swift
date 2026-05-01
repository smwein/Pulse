// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "InWorkout",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "InWorkout", targets: ["InWorkout"])],
    dependencies: [
        .package(path: "../../CoreModels"),
        .package(path: "../../DesignSystem"),
        .package(path: "../../Logging"),
        .package(path: "../../Persistence"),
        .package(path: "../../Repositories"),
        .package(name: "WatchBridge", path: "../../WatchBridge"),
        .package(path: "../WorkoutDetail"),
    ],
    targets: [
        .target(
            name: "InWorkout",
            dependencies: ["CoreModels", "DesignSystem", "Logging", "Persistence",
                           "Repositories",
                           .product(name: "WatchBridge", package: "WatchBridge"),
                           "WorkoutDetail"]
        ),
        .testTarget(
            name: "InWorkoutTests",
            dependencies: ["InWorkout", "CoreModels", "Persistence", "Repositories",
                           .product(name: "WatchBridge", package: "WatchBridge")]
        ),
    ]
)
