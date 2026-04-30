import XCTest
@testable import WatchBridge

final class WorkoutPayloadDTOTests: XCTestCase {
    func test_codec_roundTrip() throws {
        let original = WorkoutPayloadDTO(
            sessionID: UUID(),
            workoutID: UUID(),
            title: "Pull A",
            activityKind: "traditionalStrengthTraining",
            exercises: [
                .init(exerciseID: "barbell-row", name: "Barbell Row",
                      sets: [
                        .init(setNum: 1, prescribedReps: 8, prescribedLoad: "135"),
                        .init(setNum: 2, prescribedReps: 8, prescribedLoad: "135")
                      ])
            ]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WorkoutPayloadDTO.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}
