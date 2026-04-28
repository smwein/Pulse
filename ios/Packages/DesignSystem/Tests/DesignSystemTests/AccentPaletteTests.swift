import XCTest
@testable import DesignSystem

final class AccentPaletteTests: XCTestCase {
    func test_paletteHasFourTones() {
        let p = AccentPalette(hue: 45)
        XCTAssertEqual(p.base.oklch.h, 45)
        XCTAssertEqual(p.soft.oklch.h, 45)
        XCTAssertEqual(p.ink.oklch.h, 45)
        XCTAssertEqual(p.glow.oklch.h, 45)
    }

    func test_softVariantIsTransparent() {
        XCTAssertLessThan(AccentPalette(hue: 45).soft.opacity, 0.5)
    }

    func test_inkVariantIsDark() {
        // accent-ink for primary button text on accent background — must be dark
        XCTAssertLessThan(AccentPalette(hue: 45).ink.oklch.L, 0.30)
    }

    func test_differentHuesProduceDifferentColors() {
        let warm = AccentPalette(hue: 45)
        let cool = AccentPalette(hue: 220)
        XCTAssertNotEqual(warm.base.oklch.h, cool.base.oklch.h)
    }
}
