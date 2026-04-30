import XCTest
@testable import WatchBridge

final class LifecycleEventTests: XCTestCase {
    func test_started_codec() throws {
        let uuid = UUID()
        let event = LifecycleEvent.started(watchSessionUUID: uuid)
        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(LifecycleEvent.self, from: data)
        XCTAssertEqual(event, decoded)
    }
    func test_ended_codec() throws {
        let event = LifecycleEvent.ended
        let data = try JSONEncoder().encode(event)
        XCTAssertEqual(try JSONDecoder().decode(LifecycleEvent.self, from: data), event)
    }
    func test_failed_codec_allReasons() throws {
        for r in LifecycleEvent.FailureReason.allCases {
            let event = LifecycleEvent.failed(reason: r)
            let data = try JSONEncoder().encode(event)
            XCTAssertEqual(try JSONDecoder().decode(LifecycleEvent.self, from: data), event)
        }
    }
}
