import XCTest
import SwiftData
import CoreModels
import Persistence
@testable import Repositories

final class ProfileRepositoryTests: XCTestCase {
    @MainActor
    func test_currentProfile_returnsNilWhenEmpty() throws {
        let container = try PulseModelContainer.inMemory()
        let repo = ProfileRepository(modelContainer: container)
        XCTAssertNil(repo.currentProfile())
    }

    @MainActor
    func test_save_thenCurrentProfile_returnsSaved() throws {
        let container = try PulseModelContainer.inMemory()
        let repo = ProfileRepository(modelContainer: container)
        let p = Profile(id: UUID(), displayName: "Sam",
                        goals: ["build muscle"], level: .regular,
                        equipment: ["dumbbells"], frequencyPerWeek: 4,
                        weeklyTargetMinutes: 180, activeCoachID: "rex",
                        createdAt: Date())
        try repo.save(p)
        let loaded = repo.currentProfile()
        XCTAssertEqual(loaded?.displayName, "Sam")
        XCTAssertEqual(loaded?.activeCoachID, "rex")
        XCTAssertEqual(loaded?.frequencyPerWeek, 4)
    }

    @MainActor
    func test_save_isIdempotent_byID() throws {
        let container = try PulseModelContainer.inMemory()
        let repo = ProfileRepository(modelContainer: container)
        let id = UUID()
        var p = Profile(id: id, displayName: "Sam", goals: ["build muscle"],
                        level: .regular, equipment: ["dumbbells"],
                        frequencyPerWeek: 4, weeklyTargetMinutes: 180,
                        activeCoachID: "rex", createdAt: Date())
        try repo.save(p)
        p.activeCoachID = "vera"
        try repo.save(p)
        let all = try container.mainContext.fetch(FetchDescriptor<ProfileEntity>())
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.activeCoachID, "vera")
    }

    @MainActor
    func test_save_setsAccentHueFromCoach() throws {
        let container = try PulseModelContainer.inMemory()
        let repo = ProfileRepository(modelContainer: container)
        let p = Profile(id: UUID(), displayName: "Sam", goals: ["lose fat"],
                        level: .regular, equipment: ["none"],
                        frequencyPerWeek: 3, weeklyTargetMinutes: 90,
                        activeCoachID: "vera", createdAt: Date())
        try repo.save(p)
        let entity = try container.mainContext.fetch(FetchDescriptor<ProfileEntity>()).first
        XCTAssertEqual(entity?.accentHue, 220)  // Coach.byID("vera").accentHue
    }
}
