import XCTest
@testable import InWorkout

final class SmokeTests: XCTestCase {
    func test_module() { XCTAssertEqual(InWorkoutModule.name, "InWorkout") }
}
