import XCTest
import SwiftUI
@testable import DesignSystem

final class IconButtonTests: XCTestCase {
    func test_iconButtonRenders() {
        _ = IconButton(systemName: "gear", action: {}).body
    }
}
