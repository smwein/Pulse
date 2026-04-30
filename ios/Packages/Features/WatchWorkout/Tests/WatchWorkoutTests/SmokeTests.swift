import XCTest
@testable import WatchWorkout

final class WatchWorkoutSmokeTests: XCTestCase {
    func test_packageBuilds() {
        XCTAssertEqual(WatchWorkout.placeholder, "WatchWorkout alive")
    }
}
