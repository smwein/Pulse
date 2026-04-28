import XCTest
import SwiftData
@testable import Persistence

final class WorkoutEntityTests: XCTestCase {
    @MainActor
    func test_persistAndFetchWorkout() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let w = WorkoutEntity(
            id: UUID(),
            planID: UUID(),
            scheduledFor: Date(),
            title: "Lower Power",
            subtitle: "Heavy doubles",
            workoutType: "Strength",
            durationMin: 48,
            status: "scheduled",
            blocksJSON: Data("[]".utf8),
            exercisesJSON: Data("[]".utf8)
        )
        ctx.insert(w)
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<WorkoutEntity>())
        XCTAssertEqual(fetched.first?.title, "Lower Power")
        XCTAssertEqual(fetched.first?.status, "scheduled")
    }

    @MainActor
    func test_workoutEntity_storesAndReturnsWhy() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let w = WorkoutEntity(
            id: UUID(), planID: UUID(),
            scheduledFor: Date(), title: "Push", subtitle: "Upper",
            workoutType: "Strength", durationMin: 45, status: "scheduled",
            blocksJSON: Data("[]".utf8), exercisesJSON: Data("[]".utf8),
            why: "Today we hit horizontal press volume."
        )
        ctx.insert(w); try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<WorkoutEntity>()).first
        XCTAssertEqual(fetched?.why, "Today we hit horizontal press volume.")
    }
}
