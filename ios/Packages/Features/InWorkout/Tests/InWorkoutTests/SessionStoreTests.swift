import XCTest
import CoreModels
import HealthKitClient
import Persistence
import Repositories
import SwiftData
import WatchBridge
@testable import InWorkout

final class SessionStoreTests: XCTestCase {
    @MainActor
    private func makeFlat(setsPerEx: Int = 2, exerciseCount: Int = 2) -> [SessionStore.FlatEntry] {
        var out: [SessionStore.FlatEntry] = []
        for ei in 0..<exerciseCount {
            for sn in 1...setsPerEx {
                out.append(.init(blockLabel: "Main",
                                 exerciseID: "ex\(ei)",
                                 exerciseName: "Exercise \(ei)",
                                 setNum: sn,
                                 prescribedReps: 8,
                                 prescribedLoad: "60kg",
                                 restSec: 60))
            }
        }
        return out
    }

    @MainActor
    func test_initialState_pointsAtFirstSet() {
        let store = SessionStore.preview(flat: makeFlat())
        XCTAssertEqual(store.idx, 0)
        XCTAssertEqual(store.phase, .work)
        XCTAssertEqual(store.draft.reps, 8)
        XCTAssertEqual(store.draft.load, "60kg")
        XCTAssertEqual(store.draft.rpe, 0)
    }

    @MainActor
    func test_logSet_advancesWithinExercise() async {
        let store = SessionStore.preview(flat: makeFlat())
        await store.logCurrentSet()
        XCTAssertEqual(store.idx, 1)
        XCTAssertEqual(store.phase, .rest)
    }

    @MainActor
    func test_restTimerAutoAdvances() async {
        let store = SessionStore.preview(flat: makeFlat())
        await store.logCurrentSet()
        XCTAssertEqual(store.phase, .rest)
        store.tick(by: 60)
        XCTAssertEqual(store.phase, .work)
    }

    @MainActor
    func test_finishOnLastSetEmitsCompleted() async {
        let store = SessionStore.preview(flat: makeFlat(setsPerEx: 1, exerciseCount: 1))
        var completed = false
        store.onLifecycle = { event in if case .completed = event { completed = true } }
        await store.logCurrentSet()
        XCTAssertTrue(completed)
    }

    @MainActor
    func test_discardEmitsDiscardedAndResets() async {
        let store = SessionStore.preview(flat: makeFlat())
        var discarded = false
        store.onLifecycle = { event in if case .discarded = event { discarded = true } }
        await store.logCurrentSet()
        await store.discard()
        XCTAssertTrue(discarded)
    }

    @MainActor
    func test_applyRemoteSetLog_writesViaRepo() async throws {
        let (store, ctx, sessionID, _) = try await makeStoreWithStartedSession()
        let dto = SetLogDTO(sessionID: sessionID, exerciseID: "row", setNum: 1,
                            reps: 8, load: "135", rpe: nil,
                            loggedAt: Date(timeIntervalSince1970: 0))
        await store.applyRemoteSetLog(dto)
        let logs = try fetchSetLogs(ctx: ctx, sessionID: sessionID)
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].setNum, 1)
    }

    @MainActor
    func test_applyRemoteSetLog_isIdempotentByNaturalKey() async throws {
        let (store, ctx, sessionID, _) = try await makeStoreWithStartedSession()
        let dto = SetLogDTO(sessionID: sessionID, exerciseID: "row", setNum: 1,
                            reps: 8, load: "135", rpe: nil,
                            loggedAt: Date(timeIntervalSince1970: 0))
        await store.applyRemoteSetLog(dto)
        await store.applyRemoteSetLog(dto)
        let logs = try fetchSetLogs(ctx: ctx, sessionID: sessionID)
        XCTAssertEqual(logs.count, 1)
    }

    @MainActor
    func test_bridgeIncoming_appliesSetLog() async throws {
        let (store, ctx, sessionID, _) = try await makeStoreWithStartedSession()
        let transport = FakeTransport()
        let bridge = Task { await store.bridgeIncoming(transport: transport) }
        let dto = SetLogDTO(sessionID: sessionID, exerciseID: "row", setNum: 1,
            reps: 8, load: "135", rpe: nil, loggedAt: Date(timeIntervalSince1970: 0))
        await transport.simulateIncoming(.setLog(dto))
        try await Task.sleep(nanoseconds: 50_000_000)
        bridge.cancel()
        let logs = try fetchSetLogs(ctx: ctx, sessionID: sessionID)
        XCTAssertEqual(logs.count, 1)
    }

    @MainActor
    func test_bridgeIncoming_recordsWatchSessionUUID() async throws {
        let (store, _, _, _) = try await makeStoreWithStartedSession()
        let transport = FakeTransport()
        let bridge = Task { await store.bridgeIncoming(transport: transport) }
        let watchUUID = UUID()
        await transport.simulateIncoming(.sessionLifecycle(.started(watchSessionUUID: watchUUID)))
        try await Task.sleep(nanoseconds: 50_000_000)
        bridge.cancel()
        XCTAssertEqual(store.watchSessionUUID, watchUUID)
    }

    @MainActor
    func test_start_pushesPayloadWhenWatchReachable() async throws {
        let transport = FakeTransport()
        await transport.setReachable(true)
        let (store, _, workoutID) = try await makeStoreWithFreshWorkout()
        await store.startWithWatch(transport: transport)
        let sent = await transport.sent
        XCTAssertEqual(sent.count, 1)
        XCTAssertEqual(sent[0].channel, .reliable)
        if case .workoutPayload(let p) = sent[0].message {
            XCTAssertEqual(p.workoutID, workoutID)
        } else {
            XCTFail("expected payload push")
        }
    }

    @MainActor
    func test_start_skipsPushWhenWatchUnreachable() async throws {
        let transport = FakeTransport()
        await transport.setReachable(false)
        let (store, _, _) = try await makeStoreWithFreshWorkout()
        await store.startWithWatch(transport: transport)
        let sent = await transport.sent
        XCTAssertTrue(sent.isEmpty)
    }

    @MainActor
    func test_startWithWatch_requestsWriteAuthIfUndetermined() async throws {
        let transport = FakeTransport()
        await transport.setReachable(true)
        let (store, gate, _) = try await makeStoreWithFreshWorkoutAndGate(status: .undetermined)
        await store.startWithWatch(transport: transport)
        XCTAssertTrue(gate.didRequestWriteAuth)
    }

    @MainActor
    func test_startWithWatch_skipsAuthIfAlreadyAuthorized() async throws {
        let transport = FakeTransport()
        await transport.setReachable(true)
        let (store, gate, _) = try await makeStoreWithFreshWorkoutAndGate(status: .authorized)
        await store.startWithWatch(transport: transport)
        XCTAssertFalse(gate.didRequestWriteAuth)
    }

    @MainActor
    func test_startWithWatch_resetsStaleFlags() async throws {
        let transport = FakeTransport()
        let (store, _, _) = try await makeStoreWithFreshWorkout()
        // Seed stale terminal flags via the bridge.
        let bridge = Task { await store.bridgeIncoming(transport: transport) }
        await transport.simulateIncoming(.sessionLifecycle(.ended))
        await transport.simulateIncoming(.sessionLifecycle(.failed(reason: .healthKitDenied)))
        try await Task.sleep(nanoseconds: 50_000_000)
        bridge.cancel()
        XCTAssertTrue(store.watchSessionEnded)
        XCTAssertEqual(store.watchFailureReason, .healthKitDenied)
        // A fresh startWithWatch must clear them.
        await transport.setReachable(false)
        await store.startWithWatch(transport: transport)
        XCTAssertFalse(store.watchSessionEnded)
        XCTAssertNil(store.watchFailureReason)
        XCTAssertNil(store.watchSessionUUID)
    }

    @MainActor
    func test_flatten_unwrapsAllSetsAcrossBlocks() throws {
        let block = WorkoutBlock(id: "b1", label: "Main", exercises: [
            PlannedExercise(id: "e1", exerciseID: "back-squat", name: "Back Squat",
                sets: [
                    PlannedSet(setNum: 1, reps: 8, load: "60kg", restSec: 60),
                    PlannedSet(setNum: 2, reps: 8, load: "62.5kg", restSec: 60),
                ]),
            PlannedExercise(id: "e2", exerciseID: "row", name: "Row",
                sets: [PlannedSet(setNum: 1, reps: 10, load: "40kg", restSec: 45)]),
        ])
        let blocksData = try JSONEncoder.pulse.encode([block])
        let w = WorkoutEntity(id: UUID(), planID: UUID(), scheduledFor: Date(),
            title: "T", subtitle: "S", workoutType: "Strength", durationMin: 30,
            status: "scheduled", blocksJSON: blocksData,
            exercisesJSON: Data("[]".utf8))
        let flat = SessionStore.flatten(workout: w)
        XCTAssertEqual(flat.count, 3)
        XCTAssertEqual(flat[0].exerciseID, "back-squat")
        XCTAssertEqual(flat[0].setNum, 1)
        XCTAssertEqual(flat[1].setNum, 2)
        XCTAssertEqual(flat[2].exerciseID, "row")
    }

    // MARK: - Test scaffolding helpers

    @MainActor
    private func makeStoreWithStartedSession() async throws
        -> (store: SessionStore, ctx: ModelContext, sessionID: UUID, workoutID: UUID)
    {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let workout = WorkoutEntity(id: UUID(), planID: UUID(),
            scheduledFor: Date(), title: "T", subtitle: "S",
            workoutType: "Strength", durationMin: 30, status: "scheduled",
            blocksJSON: Data("[]".utf8), exercisesJSON: Data("[]".utf8))
        ctx.insert(workout)
        try ctx.save()
        let repo = SessionRepository(modelContainer: container)
        let flat = makeFlat()
        let store = SessionStore(workoutID: workout.id, flat: flat, repo: repo)
        await store.start()
        return (store, ctx, store.sessionID!, workout.id)
    }

    @MainActor
    private func makeStoreWithFreshWorkout() async throws
        -> (store: SessionStore, ctx: ModelContext, workoutID: UUID)
    {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let workout = WorkoutEntity(id: UUID(), planID: UUID(),
            scheduledFor: Date(), title: "T", subtitle: "S",
            workoutType: "Strength", durationMin: 30, status: "scheduled",
            blocksJSON: Data("[]".utf8), exercisesJSON: Data("[]".utf8))
        ctx.insert(workout); try ctx.save()
        let repo = SessionRepository(modelContainer: container)
        let store = SessionStore(workoutID: workout.id, flat: makeFlat(), repo: repo)
        return (store, ctx, workout.id)
    }

    @MainActor
    private func makeStoreWithFreshWorkoutAndGate(status: WriteAuthStatus)
        async throws -> (store: SessionStore, gate: FakeHealthKitAuthGate, workoutID: UUID)
    {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let workout = WorkoutEntity(id: UUID(), planID: UUID(),
            scheduledFor: Date(), title: "T", subtitle: "S",
            workoutType: "Strength", durationMin: 30, status: "scheduled",
            blocksJSON: Data("[]".utf8), exercisesJSON: Data("[]".utf8))
        ctx.insert(workout); try ctx.save()
        let repo = SessionRepository(modelContainer: container)
        let gate = FakeHealthKitAuthGate()
        gate.status = status
        let store = SessionStore(workoutID: workout.id, flat: makeFlat(), repo: repo, authGate: gate)
        return (store, gate, workout.id)
    }

    @MainActor
    private func fetchSetLogs(ctx: ModelContext, sessionID: UUID) throws -> [SetLogEntity] {
        let sid = sessionID
        return try ctx.fetch(FetchDescriptor<SetLogEntity>(
            predicate: #Predicate { $0.sessionID == sid }))
    }
}

private final class FakeHealthKitAuthGate: HealthKitAuthGate, @unchecked Sendable {
    var status: WriteAuthStatus = .undetermined
    var didRequestWriteAuth = false
    func writeAuthorizationStatus() -> WriteAuthStatus { status }
    func requestWriteAuthorization() async throws { didRequestWriteAuth = true }
}
