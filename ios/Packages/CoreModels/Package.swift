// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CoreModels",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "CoreModels", targets: ["CoreModels"])],
    targets: [.target(name: "CoreModels")]
)
