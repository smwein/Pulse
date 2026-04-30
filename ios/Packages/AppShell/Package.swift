// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AppShell",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "AppShell", targets: ["AppShell"])],
    dependencies: [
        .package(path: "../CoreModels"),
        .package(path: "../DesignSystem"),
        .package(path: "../Networking"),
        .package(path: "../Persistence"),
        .package(path: "../Repositories"),
        .package(path: "../HealthKitClient"),
        .package(path: "../Features/Onboarding"),
        .package(path: "../Features/Home"),
        .package(path: "../Features/PlanGeneration"),
        .package(path: "../Features/WorkoutDetail"),
        .package(path: "../Features/InWorkout"),
        .package(path: "../Features/Complete"),
    ],
    targets: [
        .target(
            name: "AppShell",
            dependencies: ["CoreModels", "DesignSystem", "Networking", "Persistence",
                           "Repositories", "HealthKitClient",
                           "Onboarding", "Home", "PlanGeneration", "WorkoutDetail",
                           "InWorkout", "Complete"]
        ),
        .testTarget(name: "AppShellTests", dependencies: ["AppShell"]),
    ]
)
