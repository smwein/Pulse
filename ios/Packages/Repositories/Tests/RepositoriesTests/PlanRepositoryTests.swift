import XCTest
import SwiftData
import CoreModels
import Networking
import Persistence
@testable import Repositories

final class PlanRepositoryTests: XCTestCase {
    @MainActor
    func test_listLatestReturnsMostRecentPlanFirst() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let older = PlanEntity(id: UUID(), weekStart: Date(timeIntervalSince1970: 1_700_000_000),
                               generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
                               modelUsed: "claude-opus-4-7", promptTokens: 100,
                               completionTokens: 100, payloadJSON: Data("{}".utf8))
        let newer = PlanEntity(id: UUID(), weekStart: Date(timeIntervalSince1970: 1_730_000_000),
                               generatedAt: Date(timeIntervalSince1970: 1_730_000_000),
                               modelUsed: "claude-opus-4-7", promptTokens: 100,
                               completionTokens: 100, payloadJSON: Data("{}".utf8))
        ctx.insert(older); ctx.insert(newer); try ctx.save()

        let repo = PlanRepository.makeForTests(modelContainer: container)
        let latest = try repo.listLatest(limit: 5)
        XCTAssertEqual(latest.first?.id, newer.id)
    }

    @MainActor
    func test_persist_alsoCreatesWorkoutEntitiesForEachPlannedWorkout() throws {
        let container = try PulseModelContainer.inMemory()
        let plan = WorkoutPlan(
            weekStart: Date(timeIntervalSince1970: 1_730_000_000),
            workouts: [
                PlannedWorkout(id: "w1",
                    scheduledFor: Date(timeIntervalSince1970: 1_730_000_000),
                    title: "Push", subtitle: "Upper",
                    workoutType: "Strength", durationMin: 45,
                    blocks: [], why: "Pressing volume."),
            ]
        )
        let repo = PlanRepository.makeForTests(modelContainer: container)
        let raw = try JSONEncoder.pulse.encode(plan)
        try repo._persistForTests(plan: plan,
            weekStart: plan.weekStart,
            modelUsed: "claude-opus-4-7",
            promptTokens: 100, completionTokens: 200, rawJSON: raw)
        let workouts = try container.mainContext.fetch(FetchDescriptor<WorkoutEntity>())
        XCTAssertEqual(workouts.count, 1)
        XCTAssertEqual(workouts.first?.title, "Push")
        XCTAssertEqual(workouts.first?.why, "Pressing volume.")
    }
}
