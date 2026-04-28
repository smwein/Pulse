import XCTest
import SwiftData
@testable import Persistence

final class WorkoutEntityTests: XCTestCase {
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
}
