// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Persistence",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "Persistence", targets: ["Persistence"])],
    dependencies: [
        .package(path: "../CoreModels"),
    ],
    targets: [
        .target(name: "Persistence", dependencies: ["CoreModels"]),
        .testTarget(name: "PersistenceTests", dependencies: ["Persistence"]),
    ]
)
