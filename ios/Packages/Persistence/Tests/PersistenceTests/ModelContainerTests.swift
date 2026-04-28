import XCTest
import SwiftData
@testable import Persistence

final class ModelContainerTests: XCTestCase {
    func test_inMemoryContainerInstantiates() throws {
        let container = try PulseModelContainer.inMemory()
        XCTAssertNotNil(container)
        XCTAssertNotNil(container.mainContext)
    }
}
