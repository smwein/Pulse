import XCTest
@testable import WatchBridge

final class WCMessageTests: XCTestCase {
    func test_workoutPayload_roundTrip() throws {
        let payload = WorkoutPayloadDTO(sessionID: UUID(), workoutID: UUID(),
            title: "T", activityKind: "k", exercises: [])
        try assertRoundTrip(.workoutPayload(payload))
    }
    func test_setLog_roundTrip() throws {
        let log = SetLogDTO(sessionID: UUID(), exerciseID: "e", setNum: 1,
            reps: 5, load: "100", rpe: 7, loggedAt: Date(timeIntervalSince1970: 0))
        try assertRoundTrip(.setLog(log))
    }
    func test_sessionLifecycle_roundTrip() throws {
        try assertRoundTrip(.sessionLifecycle(.started(watchSessionUUID: UUID())))
        try assertRoundTrip(.sessionLifecycle(.ended))
        try assertRoundTrip(.sessionLifecycle(.failed(reason: .healthKitDenied)))
    }
    func test_ack_roundTrip() throws {
        try assertRoundTrip(.ack(naturalKey: "abc|row|1"))
    }

    private func assertRoundTrip(_ msg: WCMessage,
                                  file: StaticString = #file, line: UInt = #line) throws {
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(WCMessage.self, from: data)
        XCTAssertEqual(decoded, msg, file: file, line: line)
    }
}
