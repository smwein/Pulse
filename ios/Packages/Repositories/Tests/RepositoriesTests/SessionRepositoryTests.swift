import XCTest
import SwiftData
import CoreModels
import Persistence
@testable import Repositories

final class SessionRepositoryTests: XCTestCase {
    @MainActor
    private func seedWorkout(_ ctx: ModelContext, status: String = "scheduled") -> WorkoutEntity {
        let w = WorkoutEntity(id: UUID(), planID: UUID(),
            scheduledFor: Date(), title: "Push", subtitle: "Upper",
            workoutType: "Strength", durationMin: 45, status: status,
            blocksJSON: Data("[]".utf8), exercisesJSON: Data("[]".utf8))
        ctx.insert(w); try? ctx.save()
        return w
    }

    @MainActor
    func test_start_createsSessionAndFlipsWorkoutToInProgress() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let w = seedWorkout(ctx)
        let repo = SessionRepository(modelContainer: container)
        let session = try repo.start(workoutID: w.id)
        XCTAssertEqual(session.workoutID, w.id)
        XCTAssertNotNil(session.startedAt)
        XCTAssertNil(session.completedAt)
        let refreshed = try ctx.fetch(FetchDescriptor<WorkoutEntity>()).first
        XCTAssertEqual(refreshed?.status, "in_progress")
    }

    @MainActor
    func test_logSet_isIdempotentOnTriple() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let w = seedWorkout(ctx)
        let repo = SessionRepository(modelContainer: container)
        let session = try repo.start(workoutID: w.id)
        try repo.logSet(sessionID: session.id, exerciseID: "back-squat",
                        setNum: 1, reps: 8, load: "60kg", rpe: 7)
        try repo.logSet(sessionID: session.id, exerciseID: "back-squat",
                        setNum: 1, reps: 10, load: "62.5kg", rpe: 8)
        let rows = try ctx.fetch(FetchDescriptor<SetLogEntity>())
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.reps, 10)
        XCTAssertEqual(rows.first?.load, "62.5kg")
        XCTAssertEqual(rows.first?.rpe, 8)
    }

    @MainActor
    func test_finish_setsCompletedAtAndFlipsWorkoutToCompleted() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let w = seedWorkout(ctx)
        let repo = SessionRepository(modelContainer: container)
        let session = try repo.start(workoutID: w.id)
        try repo.finish(sessionID: session.id)
        let refreshedSession = try ctx.fetch(FetchDescriptor<SessionEntity>()).first
        XCTAssertNotNil(refreshedSession?.completedAt)
        XCTAssertNotNil(refreshedSession?.durationSec)
        let refreshedWorkout = try ctx.fetch(FetchDescriptor<WorkoutEntity>()).first
        XCTAssertEqual(refreshedWorkout?.status, "completed")
    }

    @MainActor
    func test_discard_cascadeDeletesSetsAndRestoresWorkoutToScheduled() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let w = seedWorkout(ctx)
        let repo = SessionRepository(modelContainer: container)
        let session = try repo.start(workoutID: w.id)
        try repo.logSet(sessionID: session.id, exerciseID: "back-squat",
                        setNum: 1, reps: 8, load: "60kg", rpe: 7)
        try repo.discardSession(id: session.id)
        let sessions = try ctx.fetch(FetchDescriptor<SessionEntity>())
        let sets = try ctx.fetch(FetchDescriptor<SetLogEntity>())
        XCTAssertTrue(sessions.isEmpty)
        XCTAssertTrue(sets.isEmpty)
        let refreshed = try ctx.fetch(FetchDescriptor<WorkoutEntity>()).first
        XCTAssertEqual(refreshed?.status, "scheduled")
    }
}
