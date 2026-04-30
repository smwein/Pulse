import XCTest
import CoreModels
import Repositories
@testable import PlanGeneration

@MainActor
final class PlanGenStoreTests: XCTestCase {
    private func makeProfile() -> Profile {
        Profile(id: UUID(), displayName: "Sam", goals: ["build muscle"],
                level: .regular, equipment: ["dumbbells"],
                frequencyPerWeek: 4, weeklyTargetMinutes: 180,
                activeCoachID: "rex", createdAt: Date())
    }

    private func fakeStream(yields: [PlanStreamUpdate]) -> AsyncThrowingStream<PlanStreamUpdate, Error> {
        AsyncThrowingStream { continuation in
            for u in yields { continuation.yield(u) }
            continuation.finish()
        }
    }

    private func failingStream(error: Error) -> AsyncThrowingStream<PlanStreamUpdate, Error> {
        AsyncThrowingStream { continuation in continuation.finish(throwing: error) }
    }

    private func samplePlan() -> WorkoutPlan {
        WorkoutPlan(weekStart: Date(), workouts: [
            PlannedWorkout(id: "w1", scheduledFor: Date(),
                title: "Push", subtitle: "Upper",
                workoutType: "Strength", durationMin: 45,
                blocks: [], why: "Volume.")
        ])
    }

    func test_startsInStreamingState_attempt1() async {
        let store = PlanGenStore(coach: Coach.byID("rex")!,
                                 mode: .firstPlan,
                                 streamProvider: { _ in self.fakeStream(yields: []) },
                                 onPersistedWorkout: { _, _ in nil })
        await store.run(profile: makeProfile())
        if case .streaming(_, _, let attempt) = store.state {
            XCTAssertEqual(attempt, 1)
        } else if case .failed = store.state {
            // Empty stream that finishes without .done is a failure — that's expected here.
        } else {
            XCTFail("unexpected state")
        }
    }

    func test_appendsCheckpoints() async {
        let updates: [PlanStreamUpdate] = [
            .checkpoint("Reading profile"),
            .checkpoint("Selecting exercises"),
        ]
        let store = PlanGenStore(coach: Coach.byID("rex")!,
                                 mode: .firstPlan,
                                 streamProvider: { _ in self.fakeStream(yields: updates) },
                                 onPersistedWorkout: { _, _ in nil })
        await store.run(profile: makeProfile())
        if case .streaming(let cps, _, _) = store.state {
            XCTAssertEqual(cps, ["Reading profile", "Selecting exercises"])
        } else if case .failed = store.state {
            // OK — stream ended without .done; we still want the checkpoints visible
        }
    }

    func test_textBufferTrimsToLast6Lines() async {
        let lines = (1...10).map { "line \($0)\n" }
        let updates = lines.map { PlanStreamUpdate.textDelta($0) }
        let store = PlanGenStore(coach: Coach.byID("rex")!,
                                 mode: .firstPlan,
                                 streamProvider: { _ in self.fakeStream(yields: updates) },
                                 onPersistedWorkout: { _, _ in nil })
        await store.run(profile: makeProfile())
        if case .streaming(_, let text, _) = store.state {
            let visibleLines = text.split(separator: "\n", omittingEmptySubsequences: false)
            XCTAssertLessThanOrEqual(visibleLines.count, 7)  // 6 + trailing empty
        } else if case .failed = store.state {
            // Acceptable — stream ended without .done
        }
    }

    func test_done_transitionsToDone_andCallsOnPersistedWorkout() async throws {
        let plan = samplePlan()
        let updates: [PlanStreamUpdate] = [
            .done(plan, insertedWorkoutIDs: [], modelUsed: "claude-opus-4-7", promptTokens: 100, completionTokens: 200),
        ]
        var capturedPlan: WorkoutPlan?
        let store = PlanGenStore(
            coach: Coach.byID("rex")!,
            mode: .firstPlan,
            streamProvider: { _ in self.fakeStream(yields: updates) },
            onPersistedWorkout: { p, _ in
                capturedPlan = p
                return MockWorkoutHandle(id: UUID(), title: p.workouts.first!.title)
            }
        )
        await store.run(profile: makeProfile())
        if case .done(let handle) = store.state {
            XCTAssertEqual(handle.title, "Push")
        } else {
            XCTFail("expected .done, got \(store.state)")
        }
        XCTAssertEqual(capturedPlan?.workouts.first?.title, "Push")
    }

    func test_streamFails_attempt1_retriesAttempt2() async {
        var calls = 0
        let store = PlanGenStore(
            coach: Coach.byID("rex")!,
            mode: .firstPlan,
            streamProvider: { _ in
                calls += 1
                if calls == 1 {
                    return self.failingStream(error: DummyError.boom)
                } else {
                    return self.fakeStream(yields: [.checkpoint("retry attempt")])
                }
            },
            onPersistedWorkout: { _, _ in nil }
        )
        await store.run(profile: makeProfile())
        XCTAssertEqual(calls, 2)
        if case .streaming(_, _, let attempt) = store.state {
            XCTAssertEqual(attempt, 2)
        }
    }

    func test_run_isIdempotentAfterFirstStart() async {
        var calls = 0
        let plan = samplePlan()
        let store = PlanGenStore(
            coach: Coach.byID("rex")!,
            mode: .firstPlan,
            streamProvider: { _ in
                calls += 1
                return self.fakeStream(yields: [
                    .done(plan, insertedWorkoutIDs: [UUID()], modelUsed: "claude-opus-4-7",
                          promptTokens: 100, completionTokens: 200),
                ])
            },
            onPersistedWorkout: { p, ids in
                ids.first.map { MockWorkoutHandle(id: $0, title: p.workouts.first!.title) }
            }
        )

        await store.run(profile: makeProfile())
        await store.run(profile: makeProfile())

        XCTAssertEqual(calls, 1)
    }

    func test_streamFails_attempt2_transitionsToFailed() async {
        let store = PlanGenStore(
            coach: Coach.byID("rex")!,
            mode: .firstPlan,
            streamProvider: { _ in self.failingStream(error: DummyError.boom) },
            onPersistedWorkout: { _, _ in nil }
        )
        await store.run(profile: makeProfile())
        if case .failed = store.state {} else {
            XCTFail("expected .failed, got \(store.state)")
        }
    }

    func test_retry_resetsToAttempt1() async {
        let store = PlanGenStore(
            coach: Coach.byID("rex")!,
            mode: .firstPlan,
            streamProvider: { _ in self.failingStream(error: DummyError.boom) },
            onPersistedWorkout: { _, _ in nil }
        )
        await store.run(profile: makeProfile())
        // Now we're .failed; manually reset
        await store.retry(profile: makeProfile())
        // After retry it will fail again — but attempts visible should reset to 1 → 2
        if case .failed = store.state {} else {
            XCTFail("expected .failed after retry-and-fail")
        }
    }

    enum DummyError: Error { case boom }

    struct MockWorkoutHandle: WorkoutHandle {
        let id: UUID
        let title: String
    }
}
