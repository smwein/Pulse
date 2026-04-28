import XCTest
@testable import CoreModels

final class CoachTests: XCTestCase {
    func test_allCoachesHaveDistinctIDsAndHues() {
        let coaches = Coach.all
        XCTAssertEqual(coaches.count, 4)
        XCTAssertEqual(Set(coaches.map(\.id)).count, 4)
        XCTAssertEqual(Set(coaches.map(\.accentHue)).count, 4)
    }

    func test_lookupByIDReturnsExpectedCoach() {
        XCTAssertEqual(Coach.byID("ace")?.displayName, "Ace")
        XCTAssertEqual(Coach.byID("rex")?.displayName, "Rex")
        XCTAssertEqual(Coach.byID("vera")?.displayName, "Vera")
        XCTAssertEqual(Coach.byID("mira")?.displayName, "Mira")
        XCTAssertNil(Coach.byID("unknown"))
    }

    func test_aceUsesWarmOrangeHue() {
        XCTAssertEqual(Coach.byID("ace")?.accentHue, 45)
    }
}
