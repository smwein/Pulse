import XCTest
import WatchBridge
@testable import WatchWorkout

@MainActor
final class WatchSessionStoreTests: XCTestCase {
    func test_initialState_isIdle() async {
        let store = WatchSessionStore(transport: FakeTransport(),
                                      outbox: SetLogOutbox(directory: tempDir()),
                                      sessionFactory: FakeWorkoutSessionFactory())
        XCTAssertEqual(store.state, .idle)
        XCTAssertNil(store.payload)
    }

    private func tempDir() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("store-\(UUID())")
    }
}

final class FakeWorkoutSessionFactory: WorkoutSessionFactory, @unchecked Sendable {
    var startError: Error?
    var startedUUID = UUID()
    var ended = false
    var recoveredUUID: UUID?
    func startSession(activityKind: String) async throws -> UUID {
        if let e = startError { throw e }
        return startedUUID
    }
    func endSession() async throws { ended = true }
    func recoverIfActive() async -> UUID? { recoveredUUID }
}
