import XCTest
import WatchBridge
import HealthKitClient
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

    func test_start_isIdempotent_secondCallNoOps() async throws {
        let transport = FakeTransport()
        let factory = FakeWorkoutSessionFactory()
        let dir = tempDir()
        let payload = WorkoutPayloadDTO(sessionID: UUID(), workoutID: UUID(),
            title: "T", activityKind: "k", exercises: [])
        let store = WatchSessionStore(transport: transport,
                                      outbox: SetLogOutbox(directory: dir),
                                      sessionFactory: factory,
                                      payloadStorage: PayloadFileStorage(directory: dir))
        await store.receivePayload(payload)
        try await store.start()
        try await store.start()  // second call must no-op
        XCTAssertEqual(store.state, .active)
        let sent = await transport.sent
        let started = sent.filter {
            if case .sessionLifecycle(.started) = $0.message { return true } else { return false }
        }
        XCTAssertEqual(started.count, 1)
    }

    func test_confirmLastSet_autoEndsSession() async throws {
        let factory = FakeWorkoutSessionFactory()
        let payload = WorkoutPayloadDTO(sessionID: UUID(), workoutID: UUID(),
            title: "T", activityKind: "k",
            exercises: [.init(exerciseID: "row", name: "Row", sets: [
                .init(setNum: 1, prescribedReps: 8, prescribedLoad: "100")
            ])])
        let dir = tempDir()
        let transport = FakeTransport()
        let store = WatchSessionStore(transport: transport,
                                      outbox: SetLogOutbox(directory: dir),
                                      sessionFactory: factory,
                                      payloadStorage: PayloadFileStorage(directory: dir))
        await store.receivePayload(payload)
        try await store.start()
        await store.confirmCurrentSet()  // only set → auto-end
        XCTAssertEqual(store.state, .ended)
        XCTAssertTrue(factory.ended)
        let sent = await transport.sent
        let endedEvents = sent.filter { $0.message == .sessionLifecycle(.ended) }
        XCTAssertEqual(endedEvents.count, 1)
        XCTAssertEqual(endedEvents.first?.channel, .reliable)
    }

    func test_advanceFromRest_returnsToActiveOrEnds() async throws {
        let payload = WorkoutPayloadDTO(sessionID: UUID(), workoutID: UUID(),
            title: "T", activityKind: "k",
            exercises: [.init(exerciseID: "row", name: "Row", sets: [
                .init(setNum: 1, prescribedReps: 8, prescribedLoad: "100"),
                .init(setNum: 2, prescribedReps: 8, prescribedLoad: "100")
            ])])
        let dir = tempDir()
        let store = WatchSessionStore(transport: FakeTransport(),
            outbox: SetLogOutbox(directory: dir),
            sessionFactory: FakeWorkoutSessionFactory(),
            payloadStorage: PayloadFileStorage(directory: dir))
        await store.receivePayload(payload)
        try await store.start()
        await store.confirmCurrentSet()  // → resting
        if case .resting = store.state {} else { XCTFail("expected .resting") }
        await store.advanceFromRest()
        XCTAssertEqual(store.state, .active)
        await store.confirmCurrentSet()  // last set → ended (no rest)
        XCTAssertEqual(store.state, .ended)
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

    func test_start_requestsAuthIfUndetermined_andContinuesOnGrant() async throws {
        let transport = FakeTransport()
        let factory = FakeWorkoutSessionFactory()
        let dir = tempDir()
        let payload = WorkoutPayloadDTO(sessionID: UUID(), workoutID: UUID(),
            title: "T", activityKind: "k", exercises: [])
        let gate = FakeHealthKitAuthGate(initial: .undetermined, afterRequest: .authorized)
        let store = WatchSessionStore(transport: transport,
            outbox: SetLogOutbox(directory: dir),
            sessionFactory: factory,
            payloadStorage: PayloadFileStorage(directory: dir),
            authGate: gate)
        await store.receivePayload(payload)
        try await store.start()
        XCTAssertEqual(gate.requestCount, 1)
        XCTAssertEqual(store.state, .active)
    }

    func test_start_emitsHealthKitDenied_onDenial() async throws {
        let transport = FakeTransport()
        let factory = FakeWorkoutSessionFactory()
        let dir = tempDir()
        let payload = WorkoutPayloadDTO(sessionID: UUID(), workoutID: UUID(),
            title: "T", activityKind: "k", exercises: [])
        let gate = FakeHealthKitAuthGate(initial: .undetermined, afterRequest: .denied)
        let store = WatchSessionStore(transport: transport,
            outbox: SetLogOutbox(directory: dir),
            sessionFactory: factory,
            payloadStorage: PayloadFileStorage(directory: dir),
            authGate: gate)
        await store.receivePayload(payload)
        do {
            try await store.start()
            XCTFail("expected throw")
        } catch {}
        XCTAssertEqual(store.state, .failed(reason: .healthKitDenied))
        let sent = await transport.sent
        XCTAssertTrue(sent.contains(where: {
            $0.message == .sessionLifecycle(.failed(reason: .healthKitDenied))
                && $0.channel == .reliable
        }))
    }

    func test_ackDrainsOutbox() async throws {
        let transport = FakeTransport()
        let dir = tempDir()
        let outbox = SetLogOutbox(directory: dir)
        let log = SetLogDTO(sessionID: UUID(), exerciseID: "e", setNum: 1,
            reps: 5, load: "0", rpe: nil, loggedAt: Date())
        try outbox.enqueue(log)
        let store = WatchSessionStore(transport: transport, outbox: outbox,
            sessionFactory: FakeWorkoutSessionFactory(),
            payloadStorage: PayloadFileStorage(directory: dir))
        let bridge = Task { await store.bridgeIncomingAcks() }
        await transport.simulateIncoming(.ack(naturalKey: log.naturalKey))
        try await Task.sleep(nanoseconds: 50_000_000)
        bridge.cancel()
        XCTAssertEqual(try outbox.pending().count, 0)
    }

    func test_outboxReplays_onReachabilityGain() async throws {
        let transport = FakeTransport()
        await transport.setReachable(false)
        let dir = tempDir()
        let outbox = SetLogOutbox(directory: dir)
        let s = UUID()
        let a = SetLogDTO(sessionID: s, exerciseID: "e", setNum: 1, reps: 5, load: "0",
                          rpe: nil, loggedAt: Date())
        let b = SetLogDTO(sessionID: s, exerciseID: "e", setNum: 2, reps: 5, load: "0",
                          rpe: nil, loggedAt: Date())
        try outbox.enqueue(a); try outbox.enqueue(b)
        let store = WatchSessionStore(transport: transport, outbox: outbox,
            sessionFactory: FakeWorkoutSessionFactory(),
            payloadStorage: PayloadFileStorage(directory: dir))
        await transport.setReachable(true)
        await store.replayOutbox()
        let sent = await transport.sent
        let setLogs = sent.filter { if case .setLog = $0.message { return true } else { return false } }
        XCTAssertEqual(setLogs.count, 2)
    }

    private func tempDir() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("store-\(UUID())")
    }
}

private final class FakeHealthKitAuthGate: HealthKitAuthGate, @unchecked Sendable {
    var initialStatus: WriteAuthStatus
    var afterRequestStatus: WriteAuthStatus
    var requestCount = 0
    init(initial: WriteAuthStatus, afterRequest: WriteAuthStatus) {
        self.initialStatus = initial; self.afterRequestStatus = afterRequest
    }
    func writeAuthorizationStatus() -> WriteAuthStatus {
        requestCount > 0 ? afterRequestStatus : initialStatus
    }
    func requestWriteAuthorization() async throws { requestCount += 1 }
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
