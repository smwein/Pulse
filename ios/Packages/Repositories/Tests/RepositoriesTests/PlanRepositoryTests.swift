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

    @MainActor
    func test_regenerate_deletesPriorLatestWorkoutBeforeStreaming() async throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let planID = UUID()
        let priorID = UUID()
        ctx.insert(PlanEntity(id: planID,
            weekStart: Date(timeIntervalSince1970: 1_700_000_000),
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            modelUsed: "claude-opus-4-7", promptTokens: 10, completionTokens: 10,
            payloadJSON: Data("{}".utf8)))
        let prior = WorkoutEntity(id: priorID, planID: planID,
            scheduledFor: Date(timeIntervalSince1970: 1_700_000_000),
            title: "Old", subtitle: "", workoutType: "Strength",
            durationMin: 30, status: "scheduled",
            blocksJSON: Data("[]".utf8), exercisesJSON: Data("[]".utf8))
        ctx.insert(prior); try ctx.save()

        let repo = PlanRepository.makeForTests(modelContainer: container)
        // Cancel immediately — we only assert the pre-stream cleanup occurred.
        let stream = repo.regenerate(profile: ProfileRepositoryTests.fixtureProfile(),
                                      coach: Coach.byID("rex")!)
        let task = Task { for try await _ in stream {} }
        task.cancel()
        _ = try? await task.value

        // The deletion should still have happened synchronously before the stream began.
        let remaining = try ctx.fetch(FetchDescriptor<WorkoutEntity>(
            predicate: #Predicate { $0.id == priorID }))
        XCTAssertTrue(remaining.isEmpty)
    }

    @MainActor
    func test_regenerate_cascadeDeletesPriorPlanAndAllItsWorkouts() async throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let priorPlanID = UUID()
        let plan = PlanEntity(id: priorPlanID,
            weekStart: Date(timeIntervalSince1970: 1_700_000_000),
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            modelUsed: "claude-opus-4-7", promptTokens: 10, completionTokens: 10,
            payloadJSON: Data("{}".utf8))
        ctx.insert(plan)
        for i in 0..<7 {
            ctx.insert(WorkoutEntity(id: UUID(), planID: priorPlanID,
                scheduledFor: Date(timeIntervalSince1970: 1_700_000_000 + Double(i) * 86_400),
                title: "W\(i)", subtitle: "", workoutType: "Strength", durationMin: 30,
                status: "scheduled",
                blocksJSON: Data("[]".utf8), exercisesJSON: Data("[]".utf8)))
        }
        try ctx.save()

        let repo = PlanRepository.makeForTests(modelContainer: container)
        let stream = repo.regenerate(profile: ProfileRepositoryTests.fixtureProfile(),
                                     coach: Coach.byID("rex")!)
        let task = Task { for try await _ in stream {} }
        task.cancel()
        _ = try? await task.value

        // All 7 prior workouts and the prior PlanEntity should be gone.
        let remainingWorkouts = try ctx.fetch(FetchDescriptor<WorkoutEntity>(
            predicate: #Predicate { $0.planID == priorPlanID }))
        XCTAssertTrue(remainingWorkouts.isEmpty)
        let priorPlan = priorPlanID
        let remainingPlans = try ctx.fetch(FetchDescriptor<PlanEntity>(
            predicate: #Predicate { $0.id == priorPlan }))
        XCTAssertTrue(remainingPlans.isEmpty)
    }

    @MainActor
    func test_streamFirstPlan_weekStartUsesISO8601MondayBased() async throws {
        // Tuesday 2026-04-21 (UTC). ISO8601 week-of-year starts on Monday 2026-04-20.
        let tuesday = ISO8601DateFormatter().date(from: "2026-04-21T12:00:00Z")!
        var iso = Calendar(identifier: .iso8601)
        iso.timeZone = TimeZone(secondsFromGMT: 0)!
        let expectedMonday = iso.dateInterval(of: .weekOfYear, for: tuesday)!.start
        // Compare what PlanRepository would compute. Expose the helper for test
        // by adding `_weekStart(for:)` (Step 3).
        let computed = PlanRepository._weekStart(for: tuesday)
        XCTAssertEqual(computed, expectedMonday)
    }
}
