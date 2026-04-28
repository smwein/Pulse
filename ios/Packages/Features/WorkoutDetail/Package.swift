// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WorkoutDetail",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "WorkoutDetail", targets: ["WorkoutDetail"])],
    dependencies: [
        .package(path: "../../CoreModels"),
        .package(path: "../../DesignSystem"),
        .package(path: "../../Persistence"),
        .package(path: "../../Repositories"),
    ],
    targets: [
        .target(
            name: "WorkoutDetail",
            dependencies: ["CoreModels", "DesignSystem", "Persistence", "Repositories"]
        ),
        .testTarget(
            name: "WorkoutDetailTests",
            dependencies: ["WorkoutDetail", "CoreModels", "Persistence", "Repositories"]
        ),
    ]
)
