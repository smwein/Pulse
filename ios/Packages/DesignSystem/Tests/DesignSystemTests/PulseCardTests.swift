import XCTest
import SwiftUI
@testable import DesignSystem

final class PulseCardTests: XCTestCase {
    func test_cardWrapsArbitraryContent() {
        let card = PulseCard { Text("hello") }
        // Initialization must not crash; ViewBuilder closure must compile against any View.
        _ = card.body
    }
}
