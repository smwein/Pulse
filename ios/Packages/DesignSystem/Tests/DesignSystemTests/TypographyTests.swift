import XCTest
@testable import DesignSystem

final class TypographyTests: XCTestCase {
    func test_typeScaleSizesMatchDesign() {
        XCTAssertEqual(PulseFont.eyebrow.size, 11)
        XCTAssertEqual(PulseFont.h1.size, 28)
        XCTAssertEqual(PulseFont.h2.size, 22)
        XCTAssertEqual(PulseFont.h3.size, 17)
        XCTAssertEqual(PulseFont.body.size, 15)
        XCTAssertEqual(PulseFont.small.size, 13)
    }

    func test_displayUsesSerifFamily() {
        XCTAssertEqual(PulseFont.display.family, .display)
    }

    func test_eyebrowAndMonoUseMonoFamily() {
        XCTAssertEqual(PulseFont.eyebrow.family, .mono)
        XCTAssertEqual(PulseFont.mono.family, .mono)
    }
}
