import XCTest
@testable import DesignSystem

final class MetricsTests: XCTestCase {
    func test_radiiMatchDesignTokens() {
        XCTAssertEqual(PulseRadius.sm, 10)
        XCTAssertEqual(PulseRadius.md, 16)
        XCTAssertEqual(PulseRadius.lg, 22)
        XCTAssertEqual(PulseRadius.xl, 28)
    }

    func test_spacingFollows4ptGrid() {
        XCTAssertEqual(PulseSpacing.xxs, 2)
        XCTAssertEqual(PulseSpacing.xs, 4)
        XCTAssertEqual(PulseSpacing.sm, 8)
        XCTAssertEqual(PulseSpacing.md, 12)
        XCTAssertEqual(PulseSpacing.lg, 16)
        XCTAssertEqual(PulseSpacing.xl, 24)
        XCTAssertEqual(PulseSpacing.xxl, 32)
    }

    func test_motionDurationsAreNonZero() {
        XCTAssertGreaterThan(PulseMotion.fast, 0)
        XCTAssertGreaterThan(PulseMotion.standard, PulseMotion.fast)
        XCTAssertGreaterThan(PulseMotion.slow, PulseMotion.standard)
    }
}
