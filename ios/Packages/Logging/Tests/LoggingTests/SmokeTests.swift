import XCTest
@testable import Logging

final class LoggingSmokeTests: XCTestCase {
    func test_packageBuilds() {
        XCTAssertEqual(PulseLogger.placeholder, "Logging package alive")
    }
}
