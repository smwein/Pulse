import XCTest
import SwiftUI
@testable import DesignSystem

final class ColorsTests: XCTestCase {
    func test_bgScaleProgressivelyLightens() {
        // bg-0 darkest, bg-3 lightest of the dark scale
        let scale = [PulseColors.bg0, PulseColors.bg1, PulseColors.bg2, PulseColors.bg3]
        let lightnesses = scale.map { $0.oklch.L }
        XCTAssertEqual(lightnesses, lightnesses.sorted())
        XCTAssertGreaterThan(scale[3].oklch.L, scale[0].oklch.L)
    }

    func test_inkScaleProgressivelyDarkens() {
        // ink-0 brightest text → ink-3 dimmest
        let scale = [PulseColors.ink0, PulseColors.ink1, PulseColors.ink2, PulseColors.ink3]
        let lightnesses = scale.map { $0.oklch.L }
        XCTAssertEqual(lightnesses, lightnesses.sorted(by: >))
    }

    func test_goodAndWarnAreDistinctHues() {
        XCTAssertNotEqual(PulseColors.good.oklch.h, PulseColors.warn.oklch.h)
    }
}
