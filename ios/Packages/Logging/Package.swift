// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Logging",
    platforms: [.iOS(.v17), .watchOS(.v10), .macOS(.v14)],
    products: [
        .library(name: "Logging", targets: ["Logging"])
    ],
    targets: [
        .target(name: "Logging", path: "Sources/Logging"),
        .testTarget(name: "LoggingTests", dependencies: ["Logging"], path: "Tests/LoggingTests")
    ]
)
