import XCTest
import SwiftData
import Persistence
@testable import Repositories

final class WorkoutRepositoryTests: XCTestCase {
    @MainActor
    func test_todaysWorkoutReturnsScheduledForToday() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let cal = Calendar(identifier: .gregorian)
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!

        for date in [yesterday, today, tomorrow] {
            ctx.insert(WorkoutEntity(
                id: UUID(),
                planID: UUID(),
                scheduledFor: date,
                title: "T\(date.timeIntervalSince1970)",
                subtitle: "",
                workoutType: "Strength",
                durationMin: 30,
                status: "scheduled",
                blocksJSON: Data("[]".utf8),
                exercisesJSON: Data("[]".utf8)
            ))
        }
        try ctx.save()

        let repo = WorkoutRepository(modelContainer: container)
        let result = try repo.todaysWorkout(now: today.addingTimeInterval(60 * 60 * 4))
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.title.hasPrefix("T\(today.timeIntervalSince1970)"), true)
    }

    @MainActor
    func test_markCompletedUpdatesStatus() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let w = WorkoutEntity(
            id: UUID(),
            planID: UUID(),
            scheduledFor: Date(),
            title: "x",
            subtitle: "",
            workoutType: "Strength",
            durationMin: 30,
            status: "scheduled",
            blocksJSON: Data("[]".utf8),
            exercisesJSON: Data("[]".utf8)
        )
        ctx.insert(w); try ctx.save()
        let repo = WorkoutRepository(modelContainer: container)
        try repo.markCompleted(workoutID: w.id)
        let fetched = try ctx.fetch(FetchDescriptor<WorkoutEntity>()).first
        XCTAssertEqual(fetched?.status, "completed")
    }

    @MainActor
    func test_latestWorkout_returnsMostRecentByScheduledFor() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let older = WorkoutEntity(id: UUID(), planID: UUID(),
            scheduledFor: Date(timeIntervalSince1970: 1_700_000_000),
            title: "A", subtitle: "", workoutType: "Strength", durationMin: 30,
            status: "scheduled", blocksJSON: Data("[]".utf8), exercisesJSON: Data("[]".utf8))
        let newer = WorkoutEntity(id: UUID(), planID: UUID(),
            scheduledFor: Date(timeIntervalSince1970: 1_730_000_000),
            title: "B", subtitle: "", workoutType: "Strength", durationMin: 45,
            status: "scheduled", blocksJSON: Data("[]".utf8), exercisesJSON: Data("[]".utf8))
        ctx.insert(older); ctx.insert(newer); try ctx.save()
        let repo = WorkoutRepository(modelContainer: container)
        let latest = try repo.latestWorkout()
        XCTAssertEqual(latest?.title, "B")
    }

    @MainActor
    func test_latestWorkout_returnsNilWhenEmpty() throws {
        let container = try PulseModelContainer.inMemory()
        let repo = WorkoutRepository(modelContainer: container)
        XCTAssertNil(try repo.latestWorkout())
    }

    @MainActor
    func test_deleteWorkout_removesByID() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let id = UUID()
        let w = WorkoutEntity(id: id, planID: UUID(),
            scheduledFor: Date(), title: "A", subtitle: "",
            workoutType: "Strength", durationMin: 30, status: "scheduled",
            blocksJSON: Data("[]".utf8), exercisesJSON: Data("[]".utf8))
        ctx.insert(w); try ctx.save()
        let repo = WorkoutRepository(modelContainer: container)
        try repo.deleteWorkout(id: id)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<WorkoutEntity>()).count, 0)
    }
}
