import XCTest
@testable import WatchBridge

final class WCMessageUserInfoTests: XCTestCase {
    func test_userInfoRoundTrip_workoutPayload() throws {
        let payload = WorkoutPayloadDTO(sessionID: UUID(), workoutID: UUID(),
            title: "T", activityKind: "k", exercises: [])
        let msg = WCMessage.workoutPayload(payload)
        let userInfo = try msg.asUserInfo()
        let decoded = try WCMessage(userInfo: userInfo)
        XCTAssertEqual(decoded, msg)
    }
    func test_userInfoRoundTrip_setLog() throws {
        let log = SetLogDTO(sessionID: UUID(), exerciseID: "e", setNum: 1,
            reps: 5, load: "100", rpe: 7, loggedAt: Date(timeIntervalSince1970: 0))
        let msg = WCMessage.setLog(log)
        let userInfo = try msg.asUserInfo()
        XCTAssertEqual(try WCMessage(userInfo: userInfo), msg)
    }
    func test_userInfoMissingKey_throws() {
        XCTAssertThrowsError(try WCMessage(userInfo: ["nope": "x"]))
    }
}
