// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HealthKitClient",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "HealthKitClient", targets: ["HealthKitClient"])],
    targets: [
        .target(name: "HealthKitClient"),
        .testTarget(name: "HealthKitClientTests", dependencies: ["HealthKitClient"]),
    ]
)
