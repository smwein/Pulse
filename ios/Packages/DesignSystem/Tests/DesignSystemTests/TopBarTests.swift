import XCTest
import SwiftUI
@testable import DesignSystem

final class TopBarTests: XCTestCase {
    func test_topBarRendersWithAndWithoutTrailing() {
        _ = TopBar(eyebrow: "TODAY", title: "Lower Power").body
        _ = TopBar(eyebrow: "TODAY", title: "Lower Power") {
            IconButton(systemName: "gear", action: {})
        }.body
    }
}
