// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Networking",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "Networking", targets: ["Networking"])],
    dependencies: [
        .package(path: "../CoreModels"),
    ],
    targets: [
        .target(name: "Networking", dependencies: ["CoreModels"]),
        .testTarget(
            name: "NetworkingTests",
            dependencies: ["Networking"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
