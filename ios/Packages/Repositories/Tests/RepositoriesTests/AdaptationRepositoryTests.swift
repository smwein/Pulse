import XCTest
import SwiftData
import CoreModels
import Networking
import Persistence
@testable import Repositories

final class AdaptationRepositoryTests: XCTestCase {
    @MainActor
    func test_persist_supersedesOriginalAndInsertsNewWorkout() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let originalID = UUID()
        let original = WorkoutEntity(id: originalID, planID: UUID(),
            scheduledFor: Date(timeIntervalSince1970: 1_730_000_000),
            title: "Original Pull", subtitle: "", workoutType: "Strength",
            durationMin: 45, status: "scheduled",
            blocksJSON: Data("[]".utf8), exercisesJSON: Data("[]".utf8))
        ctx.insert(original); try ctx.save()
        let repo = AdaptationRepository.makeForTests(modelContainer: container)
        let payload = AdaptationPayload(
            originalWorkoutID: originalID,
            newWorkout: PlannedWorkout(id: "adapted",
                scheduledFor: Date(timeIntervalSince1970: 1_730_000_000),
                title: "Adapted Pull", subtitle: "Lighter",
                workoutType: "Strength", durationMin: 35,
                blocks: [], why: "Trimmed."),
            adjustments: [Adjustment(id: "a1", label: "Trim main", detail: "Cut one")],
            rationale: "Trimmed the load.")
        try repo.persist(payload: payload, feedbackID: UUID(),
                         appliedToPlanID: UUID(),
                         modelUsed: "claude-opus-4-7",
                         promptTokens: 100, completionTokens: 200)
        let workouts = try ctx.fetch(FetchDescriptor<WorkoutEntity>())
        XCTAssertEqual(workouts.count, 2)
        XCTAssertEqual(workouts.first(where: { $0.id == originalID })?.status, "superseded")
        XCTAssertNotNil(workouts.first(where: { $0.title == "Adapted Pull" }))
        let adaptations = try ctx.fetch(FetchDescriptor<AdaptationEntity>())
        XCTAssertEqual(adaptations.count, 1)
    }

    @MainActor
    func test_persist_throwsWhenOriginalMissing() throws {
        let container = try PulseModelContainer.inMemory()
        let repo = AdaptationRepository.makeForTests(modelContainer: container)
        let payload = AdaptationPayload(
            originalWorkoutID: UUID(),
            newWorkout: PlannedWorkout(id: "x", scheduledFor: Date(),
                title: "x", subtitle: "x", workoutType: "Strength",
                durationMin: 30, blocks: []),
            adjustments: [], rationale: "")
        XCTAssertThrowsError(try repo.persist(payload: payload,
            feedbackID: UUID(), appliedToPlanID: UUID(),
            modelUsed: "m", promptTokens: 0, completionTokens: 0))
    }

    @MainActor
    func test_persist_rollsBackOnFailure() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let repo = AdaptationRepository.makeForTests(modelContainer: container)
        let payload = AdaptationPayload(
            originalWorkoutID: UUID(),
            newWorkout: PlannedWorkout(id: "x", scheduledFor: Date(),
                title: "x", subtitle: "x", workoutType: "Strength",
                durationMin: 30, blocks: []),
            adjustments: [], rationale: "")
        _ = try? repo.persist(payload: payload,
            feedbackID: UUID(), appliedToPlanID: UUID(),
            modelUsed: "m", promptTokens: 0, completionTokens: 0)
        // No new entities should have been written — the throw happened before
        // the workout/adaptation inserts (lookup of original failed first).
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<AdaptationEntity>()).count, 0)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<WorkoutEntity>()).count, 0)
    }
}
