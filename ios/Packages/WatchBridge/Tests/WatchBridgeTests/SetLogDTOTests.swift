import XCTest
@testable import WatchBridge

final class SetLogDTOTests: XCTestCase {
    func test_codec_roundTrip() throws {
        let original = SetLogDTO(
            sessionID: UUID(),
            exerciseID: "barbell-row",
            setNum: 2,
            reps: 8,
            load: "135",
            rpe: nil,
            loggedAt: Date(timeIntervalSince1970: 1_750_000_000)
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SetLogDTO.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func test_naturalKey_combinesSessionAndExerciseAndSetNum() {
        let dto = SetLogDTO(sessionID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                            exerciseID: "row", setNum: 3, reps: 5, load: "100",
                            rpe: nil, loggedAt: Date())
        XCTAssertEqual(dto.naturalKey, "00000000-0000-0000-0000-000000000001|row|3")
    }
}
