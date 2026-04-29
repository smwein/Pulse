// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Onboarding",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "Onboarding", targets: ["Onboarding"])],
    dependencies: [
        .package(path: "../../CoreModels"),
        .package(path: "../../DesignSystem"),
        .package(path: "../../Repositories"),
        .package(path: "../../HealthKitClient"),
    ],
    targets: [
        .target(
            name: "Onboarding",
            dependencies: ["CoreModels", "DesignSystem", "Repositories", "HealthKitClient"]
        ),
        .testTarget(
            name: "OnboardingTests",
            dependencies: ["Onboarding"]
        ),
    ]
)
