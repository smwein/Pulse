import XCTest
@testable import WatchBridge

final class WatchBridgeSmokeTests: XCTestCase {
    func test_packageBuilds() {
        XCTAssertEqual(WatchBridge.placeholder, "WatchBridge alive")
    }
}
