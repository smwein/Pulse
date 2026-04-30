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

    func test_receivePayload_setsReadyAndPersists() async throws {
        let dir = tempDir()
        let payload = WorkoutPayloadDTO(sessionID: UUID(), workoutID: UUID(),
            title: "Pull A", activityKind: "traditionalStrengthTraining", exercises: [])
        let store = WatchSessionStore(transport: FakeTransport(),
                                      outbox: SetLogOutbox(directory: dir),
                                      sessionFactory: FakeWorkoutSessionFactory(),
                                      payloadStorage: PayloadFileStorage(directory: dir))
        await store.receivePayload(payload)
        XCTAssertEqual(store.state, .ready)
        XCTAssertEqual(store.payload, payload)

        let url = dir.appendingPathComponent("active-workout-payload.json")
        let data = try Data(contentsOf: url)
        let reloaded = try JSONDecoder().decode(WorkoutPayloadDTO.self, from: data)
        XCTAssertEqual(reloaded, payload)
    }

    func test_start_transitionsAndSendsLifecycle() async throws {
        let transport = FakeTransport()
        let factory = FakeWorkoutSessionFactory()
        let dir = tempDir()
        let payload = WorkoutPayloadDTO(sessionID: UUID(), workoutID: UUID(),
            title: "Pull A", activityKind: "traditionalStrengthTraining", exercises: [])
        let store = WatchSessionStore(transport: transport,
                                      outbox: SetLogOutbox(directory: dir),
                                      sessionFactory: factory,
                                      payloadStorage: PayloadFileStorage(directory: dir))
        await store.receivePayload(payload)
        try await store.start()
        XCTAssertEqual(store.state, .active)
        XCTAssertEqual(store.watchSessionUUID, factory.startedUUID)
        let sent = await transport.sent
        XCTAssertEqual(sent.count, 1)
        XCTAssertEqual(sent[0].channel, .live)
        if case .sessionLifecycle(.started(let uuid)) = sent[0].message {
            XCTAssertEqual(uuid, factory.startedUUID)
        } else {
            XCTFail("expected .sessionLifecycle(.started(...))")
        }
    }

    func test_start_failure_emitsFailedLifecycle() async throws {
        let transport = FakeTransport()
        let factory = FakeWorkoutSessionFactory()
        factory.startError = NSError(domain: "test", code: 1)
        let dir = tempDir()
        let payload = WorkoutPayloadDTO(sessionID: UUID(), workoutID: UUID(),
            title: "T", activityKind: "k", exercises: [])
        let store = WatchSessionStore(transport: transport,
                                      outbox: SetLogOutbox(directory: dir),
                                      sessionFactory: factory,
                                      payloadStorage: PayloadFileStorage(directory: dir))
        await store.receivePayload(payload)
        do {
            try await store.start()
            XCTFail("expected throw")
        } catch {}
        XCTAssertEqual(store.state, .failed(reason: .sessionStartFailed))
        let sent = await transport.sent
        XCTAssertEqual(sent.count, 1)
        XCTAssertEqual(sent[0].message, .sessionLifecycle(.failed(reason: .sessionStartFailed)))
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
