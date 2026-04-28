// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Repositories",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "Repositories", targets: ["Repositories"])],
    targets: [.target(name: "Repositories")]
)
