import XCTest
import SwiftUI
@testable import DesignSystem

final class PulsePillTests: XCTestCase {
    func test_pillRendersBothVariants() {
        _ = PulsePill("48 min").body
        _ = PulsePill("Strength", variant: .accent).body
    }
}
