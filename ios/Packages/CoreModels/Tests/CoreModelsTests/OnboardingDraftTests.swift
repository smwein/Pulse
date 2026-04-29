import XCTest
@testable import CoreModels

final class OnboardingDraftTests: XCTestCase {
    func test_emptyDraft_hasAllFieldsNil() {
        let d = OnboardingDraft()
        XCTAssertEqual(d.displayName, "")
        XCTAssertTrue(d.goals.isEmpty)
        XCTAssertNil(d.level)
        XCTAssertTrue(d.equipment.isEmpty)
        XCTAssertNil(d.frequencyPerWeek)
        XCTAssertNil(d.weeklyTargetMinutes)
        XCTAssertNil(d.activeCoachID)
    }

    func test_buildProfile_returnsNilWhenIncomplete() {
        var d = OnboardingDraft()
        d.displayName = "Sam"
        XCTAssertNil(d.buildProfile(now: Date()))
    }

    func test_buildProfile_returnsProfileWhenComplete() {
        var d = OnboardingDraft()
        d.displayName = "Sam"
        d.goals = ["build muscle"]
        d.level = .regular
        d.equipment = ["dumbbells"]
        d.frequencyPerWeek = 4
        d.weeklyTargetMinutes = 180
        d.activeCoachID = "rex"
        let p = d.buildProfile(now: Date(timeIntervalSince1970: 1_730_000_000))
        XCTAssertNotNil(p)
        XCTAssertEqual(p?.displayName, "Sam")
        XCTAssertEqual(p?.frequencyPerWeek, 4)
        XCTAssertEqual(p?.activeCoachID, "rex")
    }

    func test_canAdvance_nameStep() {
        var d = OnboardingDraft()
        XCTAssertFalse(d.canAdvance(from: .name))
        d.displayName = "   "
        XCTAssertFalse(d.canAdvance(from: .name))
        d.displayName = "Sam"
        XCTAssertTrue(d.canAdvance(from: .name))
    }

    func test_canAdvance_goalsStep() {
        var d = OnboardingDraft()
        XCTAssertFalse(d.canAdvance(from: .goals))
        d.goals = ["lose fat"]
        XCTAssertTrue(d.canAdvance(from: .goals))
    }

    func test_canAdvance_frequencyStep_requiresBoth() {
        var d = OnboardingDraft()
        d.frequencyPerWeek = 4
        XCTAssertFalse(d.canAdvance(from: .frequency))
        d.weeklyTargetMinutes = 180
        XCTAssertTrue(d.canAdvance(from: .frequency))
    }

    func test_step_healthExistsBetweenCoachAndEnd() {
        let all = OnboardingDraft.Step.allCases
        XCTAssertTrue(all.contains(.health))
        // Order: ... coach < health
        XCTAssertLessThan(OnboardingDraft.Step.coach.rawValue,
                          OnboardingDraft.Step.health.rawValue)
    }

    func test_canAdvance_healthStep_alwaysTrue() {
        let d = OnboardingDraft()
        XCTAssertTrue(d.canAdvance(from: .health))
    }
}
