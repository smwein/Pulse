import XCTest
import SwiftUI
@testable import DesignSystem

final class RingTests: XCTestCase {
    func test_ringClampsProgressToZeroOne() {
        XCTAssertEqual(Ring(progress: -0.5).clampedProgress, 0)
        XCTAssertEqual(Ring(progress: 1.7).clampedProgress, 1)
        XCTAssertEqual(Ring(progress: 0.42).clampedProgress, 0.42, accuracy: 0.0001)
    }

    func test_ringRenders() {
        _ = Ring(progress: 0.65, size: 120, lineWidth: 10).body
    }
}
