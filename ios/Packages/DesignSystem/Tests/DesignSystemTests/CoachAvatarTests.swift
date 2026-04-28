import XCTest
import SwiftUI
import CoreModels
@testable import DesignSystem

final class CoachAvatarTests: XCTestCase {
    func test_avatarRendersForEachCoach() {
        for coach in Coach.all {
            _ = CoachAvatar(coach: coach, size: 56).body
        }
    }
}
