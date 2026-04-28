import XCTest
@testable import DesignSystem

final class OklchTests: XCTestCase {
    func test_pureBlackOklchProducesSrgbZero() {
        let rgb = Oklch(L: 0, C: 0, h: 0).toLinearSrgb().toSrgb()
        XCTAssertEqual(rgb.r, 0, accuracy: 0.005)
        XCTAssertEqual(rgb.g, 0, accuracy: 0.005)
        XCTAssertEqual(rgb.b, 0, accuracy: 0.005)
    }

    func test_pureWhiteOklchProducesSrgbOne() {
        let rgb = Oklch(L: 1, C: 0, h: 0).toLinearSrgb().toSrgb()
        XCTAssertEqual(rgb.r, 1, accuracy: 0.01)
        XCTAssertEqual(rgb.g, 1, accuracy: 0.01)
        XCTAssertEqual(rgb.b, 1, accuracy: 0.01)
    }

    func test_warmAccentOrangeMatchesDesignToken() {
        // --accent: oklch(72% 0.18 45) — warm hot orange
        // Reference computed via the CSS Color 4 oklch→sRGB pipeline (Björn Ottosson):
        // ≈ rgb(254, 123, 53) → (0.997, 0.481, 0.209)
        let rgb = Oklch(L: 0.72, C: 0.18, h: 45).toLinearSrgb().toSrgb()
        XCTAssertEqual(rgb.r, 0.997, accuracy: 0.02)
        XCTAssertEqual(rgb.g, 0.481, accuracy: 0.02)
        XCTAssertEqual(rgb.b, 0.209, accuracy: 0.02)
        // Sanity: it's a saturated warm orange — R dominates, B is small.
        XCTAssertGreaterThan(rgb.r, rgb.g)
        XCTAssertGreaterThan(rgb.g, rgb.b)
    }

    func test_deepBackgroundOklchIsNearBlack() {
        // --bg-0: oklch(16% 0.005 60)
        let rgb = Oklch(L: 0.16, C: 0.005, h: 60).toLinearSrgb().toSrgb()
        XCTAssertLessThan(rgb.r, 0.10)
        XCTAssertLessThan(rgb.g, 0.10)
        XCTAssertLessThan(rgb.b, 0.10)
        XCTAssertEqual(rgb.r, rgb.g, accuracy: 0.04)  // near-neutral
    }
}
