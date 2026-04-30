// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Complete",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "Complete", targets: ["Complete"])],
    dependencies: [
        .package(path: "../../CoreModels"),
        .package(path: "../../DesignSystem"),
        .package(path: "../../Persistence"),
        .package(path: "../../Networking"),
        .package(path: "../../Repositories"),
        .package(path: "../../HealthKitClient"),
    ],
    targets: [
        .target(
            name: "Complete",
            dependencies: ["CoreModels", "DesignSystem", "Persistence",
                           "Networking", "Repositories", "HealthKitClient"]
        ),
        .testTarget(
            name: "CompleteTests",
            dependencies: ["Complete", "CoreModels", "Persistence", "Repositories"]
        ),
    ]
)
