import XCTest
import CoreModels
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
    func test_start_restoresProgressFromExistingSession() async throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let workoutID = UUID()
        let workout = WorkoutEntity(id: workoutID, planID: UUID(), scheduledFor: Date(),
            title: "T", subtitle: "S", workoutType: "Strength", durationMin: 30,
            status: "in_progress", blocksJSON: Data("[]".utf8),
            exercisesJSON: Data("[]".utf8))
        ctx.insert(workout)
        let session = SessionEntity(id: UUID(), workoutID: workoutID, startedAt: Date())
        ctx.insert(session)
        ctx.insert(SetLogEntity(sessionID: session.id, exerciseID: "ex0",
                                setNum: 1, reps: 8, load: "60kg", rpe: 7,
                                loggedAt: Date(), session: session))
        try ctx.save()

        let store = SessionStore(workoutID: workoutID, flat: makeFlat(),
                                 repo: SessionRepository(modelContainer: container))
        await store.start()

        XCTAssertEqual(store.sessionID, session.id)
        XCTAssertEqual(store.idx, 1)
        XCTAssertEqual(store.current?.setNum, 2)
    }

    @MainActor
    func test_start_sendsWatchPayload() async throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let workoutID = UUID()
        ctx.insert(WorkoutEntity(id: workoutID, planID: UUID(), scheduledFor: Date(),
            title: "Upper", subtitle: "S", workoutType: "Strength", durationMin: 30,
            status: "scheduled", blocksJSON: Data("[]".utf8),
            exercisesJSON: Data("[]".utf8)))
        try ctx.save()
        let transport = FakeTransport()
        let store = SessionStore(workoutID: workoutID, flat: makeFlat(setsPerEx: 2, exerciseCount: 1),
                                 repo: SessionRepository(modelContainer: container),
                                 watchTransport: transport,
                                 workoutTitle: "Upper",
                                 activityKind: "traditionalStrengthTraining")

        await store.start()

        let sent = await transport.sent
        XCTAssertEqual(sent.count, 1)
        XCTAssertEqual(sent.first?.channel, .reliable)
        if case .workoutPayload(let payload) = sent.first?.message {
            XCTAssertEqual(payload.title, "Upper")
            XCTAssertEqual(payload.workoutID, workoutID)
            XCTAssertEqual(payload.exercises.count, 1)
            XCTAssertEqual(payload.exercises.first?.sets.count, 2)
        } else {
            XCTFail("expected workout payload")
        }
    }

    @MainActor
    func test_logCurrentSet_mirrorsPhoneSetToWatch() async throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let workoutID = UUID()
        ctx.insert(WorkoutEntity(id: workoutID, planID: UUID(), scheduledFor: Date(),
            title: "Upper", subtitle: "S", workoutType: "Strength", durationMin: 30,
            status: "scheduled", blocksJSON: Data("[]".utf8),
            exercisesJSON: Data("[]".utf8)))
        try ctx.save()
        let transport = FakeTransport()
        let store = SessionStore(workoutID: workoutID, flat: makeFlat(setsPerEx: 2, exerciseCount: 1),
                                 repo: SessionRepository(modelContainer: container),
                                 watchTransport: transport)
        await store.start()

        await store.logCurrentSet()

        let sent = await transport.sent
        XCTAssertTrue(sent.contains {
            if case .setLog(let log) = $0.message {
                return log.exerciseID == "ex0" && log.setNum == 1 && $0.channel == .live
            }
            return false
        })
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

    @MainActor
    func test_watchExercises_groupsFlatEntriesByExercise() {
        let payloadExercises = SessionStore.watchExercises(from: makeFlat(setsPerEx: 2, exerciseCount: 2))
        XCTAssertEqual(payloadExercises.count, 2)
        XCTAssertEqual(payloadExercises[0].exerciseID, "ex0")
        XCTAssertEqual(payloadExercises[0].sets.map(\.setNum), [1, 2])
        XCTAssertEqual(payloadExercises[1].exerciseID, "ex1")
    }
}
