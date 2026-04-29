import XCTest
@testable import CoreModels

final class AdaptationDiffTests: XCTestCase {
    func test_diffWithMixedChangesRoundTrips() throws {
        let diff = AdaptationDiff(
            generatedAt: Date(timeIntervalSince1970: 1_730_001_000),
            rationale: "Reduced lower-body volume after rough mood + RPE 9 squats.",
            changes: [
                .swap(from: "back_squat", to: "goblet_squat", reason: "Lighter load, same pattern"),
                .reps(exerciseID: "deadlift", from: 5, to: 3, reason: "Heavier intent"),
                .remove(exerciseID: "burpee", reason: "Recovery day"),
                .add(exerciseID: "pigeon_pose", afterExerciseID: nil, reason: "Hip mobility add-on"),
            ]
        )
        let data = try JSONEncoder.pulse.encode(diff)
        let decoded = try JSONDecoder.pulse.decode(AdaptationDiff.self, from: data)
        XCTAssertEqual(diff, decoded)
        XCTAssertEqual(decoded.changes.count, 4)
    }

    func test_adaptationPayload_codableRoundTrip() throws {
        let pw = PlannedWorkout(id: "w1",
            scheduledFor: Date(timeIntervalSince1970: 1_730_000_000),
            title: "Push", subtitle: "Upper",
            workoutType: "Strength", durationMin: 45,
            blocks: [], why: "Focus on bilateral pressing volume.")
        let payload = AdaptationPayload(originalWorkoutID: UUID(),
            newWorkout: pw,
            adjustments: [
                Adjustment(id: "a1", label: "Trim main", detail: "Drop one accessory pair"),
                Adjustment(id: "a2", label: "Bilateral focus", detail: "Replace 3 unilateral moves"),
            ],
            rationale: "You felt this was too long; we trimmed it and held the strength stimulus.")
        let data = try JSONEncoder.pulse.encode(payload)
        let round = try JSONDecoder.pulse.decode(AdaptationPayload.self, from: data)
        XCTAssertEqual(round.adjustments.count, 2)
        XCTAssertEqual(round.newWorkout.title, "Push")
    }

    func test_adjustment_id_isStable() {
        let a = Adjustment(id: "x", label: "L", detail: "D")
        XCTAssertEqual(a.id, "x")
    }
}
