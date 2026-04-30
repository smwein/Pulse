import XCTest
@testable import Logging

final class PulseLoggerTests: XCTestCase {
    func test_categoryLoggers_haveExpectedSubsystem() {
        XCTAssertEqual(PulseLogger.bridge.category, "bridge")
        XCTAssertEqual(PulseLogger.session.category, "session")
        XCTAssertEqual(PulseLogger.healthkit.category, "healthkit")
        XCTAssertEqual(PulseLogger.repo.category, "repo")
    }

    func test_subsystem_isPulseBundleID() {
        XCTAssertEqual(PulseLogger.bridge.subsystem, "co.simpleav.pulse")
    }
}
