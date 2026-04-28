import XCTest
import CoreModels
@testable import DesignSystem

final class ThemeStoreTests: XCTestCase {
    func test_defaultsToAceWarmOrange() {
        let store = ThemeStore()
        XCTAssertEqual(store.activeCoachID, "ace")
        XCTAssertEqual(store.accent.hue, 45)
    }

    func test_settingActiveCoachUpdatesAccentImmediately() {
        let store = ThemeStore()
        store.setActiveCoach(id: "vera")
        XCTAssertEqual(store.activeCoachID, "vera")
        XCTAssertEqual(store.accent.hue, 220)
    }

    func test_unknownCoachIDIsIgnored() {
        let store = ThemeStore()
        store.setActiveCoach(id: "nope")
        XCTAssertEqual(store.activeCoachID, "ace")
    }
}
