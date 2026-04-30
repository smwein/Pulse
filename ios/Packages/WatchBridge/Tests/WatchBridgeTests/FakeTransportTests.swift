import XCTest
@testable import WatchBridge

final class FakeTransportTests: XCTestCase {
    func test_send_recordsInOrder() async throws {
        let t = FakeTransport()
        let log = SetLogDTO(sessionID: UUID(), exerciseID: "e", setNum: 1,
            reps: 5, load: "100", rpe: nil, loggedAt: Date(timeIntervalSince1970: 0))
        try await t.send(.setLog(log), via: .reliable)
        try await t.send(.sessionLifecycle(.ended), via: .live)
        let sent = await t.sent
        XCTAssertEqual(sent.count, 2)
        XCTAssertEqual(sent[0].channel, .reliable)
        XCTAssertEqual(sent[1].channel, .live)
    }

    func test_inbox_publishesReceivedMessages() async throws {
        let t = FakeTransport()
        var received: [WCMessage] = []
        let task = Task {
            for await msg in await t.incoming { received.append(msg) }
        }
        await t.simulateIncoming(.sessionLifecycle(.ended))
        try await Task.sleep(nanoseconds: 10_000_000)
        task.cancel()
        XCTAssertEqual(received, [.sessionLifecycle(.ended)])
    }

    func test_isReachable_initiallyFalse() async {
        let t = FakeTransport()
        let r = await t.isReachable
        XCTAssertFalse(r)
    }
}
