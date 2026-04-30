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

    func test_activeSetView_renders() {
        let v = ActiveSetView(exerciseName: "Row", setNum: 1, totalSets: 3,
                              prescribedReps: 8, prescribedLoad: "100",
                              onConfirm: {})
        _ = v.body
    }

    func test_restView_renders() {
        _ = RestView(secondsRemaining: 60, onSkip: {}).body
    }

    @MainActor func test_watchAppRoot_renders() async {
        let store = WatchSessionStore(transport: FakeTransport(),
            outbox: SetLogOutbox(directory: FileManager.default.temporaryDirectory),
            sessionFactory: FakeWorkoutSessionFactory(),
            payloadStorage: PayloadFileStorage(directory: FileManager.default.temporaryDirectory))
        _ = WatchAppRoot(store: store).body
    }
}
