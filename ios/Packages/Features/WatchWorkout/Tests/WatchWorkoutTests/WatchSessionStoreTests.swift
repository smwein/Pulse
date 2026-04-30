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
        XCTAssertEqual(sent[0].channel, .reliable)
    }

    func test_currentExercise_andSetNum_advanceWithLogs() async throws {
        let payload = WorkoutPayloadDTO(sessionID: UUID(), workoutID: UUID(),
            title: "T", activityKind: "k",
            exercises: [
                .init(exerciseID: "row", name: "Row", sets: [
                    .init(setNum: 1, prescribedReps: 8, prescribedLoad: "100"),
                    .init(setNum: 2, prescribedReps: 8, prescribedLoad: "100")
                ]),
                .init(exerciseID: "press", name: "Press", sets: [
                    .init(setNum: 1, prescribedReps: 5, prescribedLoad: "60")
                ])
            ])
        let dir = tempDir()
        let transport = FakeTransport()
        let store = WatchSessionStore(transport: transport,
                                      outbox: SetLogOutbox(directory: dir),
                                      sessionFactory: FakeWorkoutSessionFactory(),
                                      payloadStorage: PayloadFileStorage(directory: dir))
        await store.receivePayload(payload)
        try await store.start()

        XCTAssertEqual(store.currentExerciseID, "row")
        XCTAssertEqual(store.currentSetNum, 1)

        await store.confirmCurrentSet()  // advances
        XCTAssertEqual(store.currentExerciseID, "row")
        XCTAssertEqual(store.currentSetNum, 2)

        await store.confirmCurrentSet()  // advances to next exercise
        XCTAssertEqual(store.currentExerciseID, "press")
        XCTAssertEqual(store.currentSetNum, 1)

        await store.confirmCurrentSet()  // last set of "press"

        let pendingFinal = try SetLogOutbox(directory: dir).pending()
        XCTAssertEqual(pendingFinal.count, 3)
        let sent = await transport.sent
        let setLogSends = sent.filter { if case .setLog = $0.message { return true } else { return false } }
        XCTAssertEqual(setLogSends.count, 3)
        XCTAssertTrue(setLogSends.allSatisfy { $0.channel == .reliable })
    }

    func test_endSession_callsFactoryAndEmitsLifecycle() async throws {
        let transport = FakeTransport()
        let factory = FakeWorkoutSessionFactory()
        let dir = tempDir()
        let payload = WorkoutPayloadDTO(sessionID: UUID(), workoutID: UUID(),
            title: "T", activityKind: "k", exercises: [])
        let store = WatchSessionStore(transport: transport, outbox: SetLogOutbox(directory: dir),
            sessionFactory: factory,
            payloadStorage: PayloadFileStorage(directory: dir))
        await store.receivePayload(payload)
        try await store.start()
        try await store.endSession()
        XCTAssertTrue(factory.ended)
        XCTAssertEqual(store.state, .ended)
        let lastSent = await transport.sent.last
        XCTAssertEqual(lastSent?.message, .sessionLifecycle(.ended))
        XCTAssertEqual(lastSent?.channel, .reliable)
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
