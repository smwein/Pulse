import XCTest
@testable import HealthKitClient

final class SmokeTests: XCTestCase {
    func test_module_compiles() {
        // Real tests land in Task 2.2. This test exists so the test target builds clean.
        let client = HealthKitClient(store: nil)
        XCTAssertNotNil(client as Any)
    }
}
