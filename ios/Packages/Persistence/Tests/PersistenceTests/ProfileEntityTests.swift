import XCTest
import SwiftData
@testable import Persistence

final class ProfileEntityTests: XCTestCase {
    @MainActor
    func test_persistAndFetchProfile() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let p = ProfileEntity(id: UUID(), displayName: "Steven",
                              goals: ["strength"], level: "regular",
                              equipment: ["barbell"], frequencyPerWeek: 4,
                              weeklyTargetMinutes: 200, activeCoachID: "ace",
                              accentHue: 45, createdAt: Date())
        ctx.insert(p)
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<ProfileEntity>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.displayName, "Steven")
    }
}
