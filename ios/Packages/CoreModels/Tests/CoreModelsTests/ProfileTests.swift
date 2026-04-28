import XCTest
@testable import CoreModels

final class ProfileTests: XCTestCase {
    func test_profileBuildsFromOnboardingInputs() {
        let p = Profile(
            id: UUID(),
            displayName: "Steven",
            goals: ["build strength", "stay mobile"],
            level: .regular,
            equipment: ["dumbbells", "barbell", "bench"],
            frequencyPerWeek: 4,
            weeklyTargetMinutes: 200,
            activeCoachID: "ace",
            createdAt: Date()
        )
        XCTAssertEqual(p.activeCoachID, "ace")
        XCTAssertEqual(Coach.byID(p.activeCoachID)?.accentHue, 45)
    }
}
