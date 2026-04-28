import XCTest
import SwiftUI
@testable import DesignSystem

final class PulseButtonTests: XCTestCase {
    func test_buttonRendersAllVariantsWithoutCrash() {
        for variant in [PulseButton.Variant.primary, .ghost] {
            for size in [PulseButton.Size.regular, .large] {
                let button = PulseButton("Start", variant: variant, size: size, action: {})
                _ = button.body
            }
        }
    }

    func test_buttonInvokesActionClosureType() {
        var fired = false
        let button = PulseButton("Tap", action: { fired = true })
        _ = button.body
        // Direct closure invocation as a sanity check on capture
        button.action()
        XCTAssertTrue(fired)
    }
}
