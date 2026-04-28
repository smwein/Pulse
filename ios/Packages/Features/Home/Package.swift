// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Home",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "Home", targets: ["Home"])],
    dependencies: [
        .package(path: "../../CoreModels"),
        .package(path: "../../DesignSystem"),
        .package(path: "../../Persistence"),
        .package(path: "../../Repositories"),
    ],
    targets: [
        .target(
            name: "Home",
            dependencies: ["CoreModels", "DesignSystem", "Persistence", "Repositories"]
        ),
        .testTarget(
            name: "HomeTests",
            dependencies: ["Home", "CoreModels", "Persistence", "Repositories"]
        ),
    ]
)
