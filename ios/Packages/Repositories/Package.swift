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
    ],
    targets: [
        .target(
            name: "Repositories",
            dependencies: ["CoreModels", "Persistence", "Networking"]
        ),
        .testTarget(name: "RepositoriesTests", dependencies: ["Repositories"]),
    ]
)
