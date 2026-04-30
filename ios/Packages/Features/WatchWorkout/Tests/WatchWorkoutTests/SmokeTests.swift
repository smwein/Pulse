import XCTest
import SwiftUI
import WatchBridge
@testable import WatchWorkout

final class WatchWorkoutSmokeTests: XCTestCase {
    func test_packageBuilds() {
        XCTAssertEqual(WatchWorkout.placeholder, "WatchWorkout alive")
    }

    func test_idleView_rendersBothStates() {
        let withPayload = IdleView(payload: WorkoutPayloadDTO(sessionID: UUID(),
            workoutID: UUID(), title: "T", activityKind: "k", exercises: []),
            onStart: {})
        let waiting = IdleView(payload: nil, onStart: {})
        _ = withPayload.body
        _ = waiting.body
    }
}
