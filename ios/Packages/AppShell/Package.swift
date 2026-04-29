// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AppShell",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "AppShell", targets: ["AppShell"])],
    dependencies: [
        .package(path: "../DesignSystem"),
        .package(path: "../Repositories"),
        .package(path: "../HealthKitClient"),
        .package(path: "../Features/Onboarding"),
        .package(path: "../Features/Home"),
        .package(path: "../Features/PlanGeneration"),
        .package(path: "../Features/WorkoutDetail"),
    ],
    targets: [
        .target(name: "AppShell", dependencies: ["DesignSystem", "Repositories", "HealthKitClient",
                                                  "Onboarding", "Home", "PlanGeneration", "WorkoutDetail"]),
        .testTarget(name: "AppShellTests", dependencies: ["AppShell"]),
    ]
)
