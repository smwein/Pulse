// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PlanGeneration",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "PlanGeneration", targets: ["PlanGeneration"])],
    dependencies: [
        .package(path: "../../CoreModels"),
        .package(path: "../../DesignSystem"),
        .package(path: "../../Persistence"),
        .package(path: "../../Repositories"),
    ],
    targets: [
        .target(
            name: "PlanGeneration",
            dependencies: ["CoreModels", "DesignSystem", "Persistence", "Repositories"]
        ),
        .testTarget(
            name: "PlanGenerationTests",
            dependencies: ["PlanGeneration"]
        ),
    ]
)
