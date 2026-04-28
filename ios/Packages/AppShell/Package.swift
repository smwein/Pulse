// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AppShell",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "AppShell", targets: ["AppShell"])],
    targets: [.target(name: "AppShell")]
)
