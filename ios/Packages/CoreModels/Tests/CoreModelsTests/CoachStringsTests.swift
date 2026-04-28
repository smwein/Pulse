import XCTest
@testable import CoreModels

final class CoachStringsTests: XCTestCase {
    func test_allCoachIDsHaveOnboardingWelcome() {
        for coach in Coach.all {
            XCTAssertNotNil(CoachStrings.onboardingWelcome[coach.id], "missing onboardingWelcome for \(coach.id)")
        }
    }

    func test_allCoachIDsHavePlanGenHeader() {
        for coach in Coach.all {
            XCTAssertNotNil(CoachStrings.planGenHeader[coach.id], "missing planGenHeader for \(coach.id)")
        }
    }

    func test_allCoachIDsHaveHomeGreeting() {
        for coach in Coach.all {
            XCTAssertNotNil(CoachStrings.homeGreeting[coach.id], "missing homeGreeting for \(coach.id)")
        }
    }

    func test_lookupHelpersFallBackOnUnknownCoach() {
        XCTAssertEqual(CoachStrings.onboardingWelcome(for: "nonsense"), CoachStrings.onboardingWelcome["ace"])
        XCTAssertEqual(CoachStrings.planGenHeader(for: "nonsense"), CoachStrings.planGenHeader["ace"])
        XCTAssertEqual(CoachStrings.homeGreeting(for: "nonsense"), CoachStrings.homeGreeting["ace"])
    }
}
