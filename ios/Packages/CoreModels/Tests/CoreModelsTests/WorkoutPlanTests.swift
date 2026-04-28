import XCTest
@testable import CoreModels

final class WorkoutPlanTests: XCTestCase {
    func test_decodesSampleFixture() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "sample-plan", withExtension: "json", subdirectory: "Fixtures"))
        let data = try Data(contentsOf: url)
        let plan = try JSONDecoder.pulse.decode(WorkoutPlan.self, from: data)

        XCTAssertEqual(plan.workouts.count, 1)
        let workout = plan.workouts[0]
        XCTAssertEqual(workout.title, "Lower Power")
        XCTAssertEqual(workout.workoutType, "Strength")
        XCTAssertEqual(workout.durationMin, 48)
        XCTAssertEqual(workout.blocks.count, 2)
        XCTAssertEqual(workout.blocks[1].exercises[0].sets.count, 3)
        XCTAssertEqual(workout.blocks[1].exercises[0].sets[2].load, "92 kg")
    }

    func test_roundTripPreservesShape() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "sample-plan", withExtension: "json", subdirectory: "Fixtures"))
        let data = try Data(contentsOf: url)
        let original = try JSONDecoder.pulse.decode(WorkoutPlan.self, from: data)
        let encoded = try JSONEncoder.pulse.encode(original)
        let decoded = try JSONDecoder.pulse.decode(WorkoutPlan.self, from: encoded)
        XCTAssertEqual(original, decoded)
    }

    func test_plannedWorkout_decodesWhyFieldFromJSON() throws {
        let json = #"""
        {"id":"w1","scheduledFor":"2026-04-28T00:00:00Z","title":"Push","subtitle":"Upper body","workoutType":"Strength","durationMin":45,"blocks":[],"why":"Today we focus on horizontal pressing volume."}
        """#
        let pw = try JSONDecoder.pulse.decode(PlannedWorkout.self, from: Data(json.utf8))
        XCTAssertEqual(pw.why, "Today we focus on horizontal pressing volume.")
    }

    func test_plannedWorkout_decodesWithMissingWhy() throws {
        let json = #"""
        {"id":"w1","scheduledFor":"2026-04-28T00:00:00Z","title":"Push","subtitle":"Upper body","workoutType":"Strength","durationMin":45,"blocks":[]}
        """#
        let pw = try JSONDecoder.pulse.decode(PlannedWorkout.self, from: Data(json.utf8))
        XCTAssertNil(pw.why)
    }
}
