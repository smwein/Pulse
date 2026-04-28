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
}
