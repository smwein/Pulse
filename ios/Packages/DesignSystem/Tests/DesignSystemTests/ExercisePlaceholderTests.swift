import XCTest
import SwiftUI
@testable import DesignSystem

final class ExercisePlaceholderTests: XCTestCase {
    func test_placeholderRenders() {
        _ = ExercisePlaceholder(label: "BACK SQUAT").body
    }
}
