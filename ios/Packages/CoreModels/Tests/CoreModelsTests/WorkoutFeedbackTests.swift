import XCTest
@testable import CoreModels

final class WorkoutFeedbackTests: XCTestCase {
    func test_feedbackEncodesAllFields() throws {
        let fb = WorkoutFeedback(
            sessionID: UUID(),
            submittedAt: Date(timeIntervalSince1970: 1_730_000_000),
            rating: 4,
            intensity: 3,
            mood: .good,
            tags: ["energized", "form-good"],
            exerciseRatings: ["ex-002": .up, "ex-001": .down],
            note: "Felt strong on the squats"
        )
        let data = try JSONEncoder.pulse.encode(fb)
        let decoded = try JSONDecoder.pulse.decode(WorkoutFeedback.self, from: data)
        XCTAssertEqual(fb, decoded)
        XCTAssertEqual(decoded.exerciseRatings["ex-002"], .up)
    }

    func test_setLogEntryRoundTrip() throws {
        let entry = SetLogEntry(
            exerciseID: "ex-002",
            setNum: 2,
            reps: 5,
            load: "80 kg",
            rpe: 8,
            loggedAt: Date(timeIntervalSince1970: 1_730_000_500)
        )
        let data = try JSONEncoder.pulse.encode(entry)
        let decoded = try JSONDecoder.pulse.decode(SetLogEntry.self, from: data)
        XCTAssertEqual(entry, decoded)
    }
}
