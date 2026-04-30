import XCTest
import CoreModels
import Persistence
import SwiftData
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
}
