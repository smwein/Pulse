import XCTest
import SwiftData
@testable import Persistence

final class TransactionTests: XCTestCase {
    @MainActor
    func test_atomicWrite_rollsBackOnThrow() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let initialCount = try ctx.fetch(FetchDescriptor<ProfileEntity>()).count
        struct Boom: Error {}
        do {
            try ctx.atomicWrite {
                ctx.insert(ProfileEntity(id: UUID(), displayName: "x", goals: ["g"],
                    level: "regular", equipment: ["dumbbells"], frequencyPerWeek: 3,
                    weeklyTargetMinutes: 120, activeCoachID: "rex", accentHue: 45,
                    createdAt: Date()))
                throw Boom()
            }
            XCTFail("expected throw")
        } catch {
            // expected
        }
        let after = try ctx.fetch(FetchDescriptor<ProfileEntity>()).count
        XCTAssertEqual(after, initialCount)
    }

    @MainActor
    func test_atomicWrite_commitsOnSuccess() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        try ctx.atomicWrite {
            ctx.insert(ProfileEntity(id: UUID(), displayName: "y", goals: ["g"],
                level: "regular", equipment: ["dumbbells"], frequencyPerWeek: 3,
                weeklyTargetMinutes: 120, activeCoachID: "rex", accentHue: 45,
                createdAt: Date()))
        }
        let count = try ctx.fetch(FetchDescriptor<ProfileEntity>()).count
        XCTAssertEqual(count, 1)
    }
}
