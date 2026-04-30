import XCTest
@testable import Complete

final class SmokeTests: XCTestCase {
    func test_module() { XCTAssertEqual(CompleteModule.name, "Complete") }
}
