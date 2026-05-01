import XCTest
import SwiftData
import CoreModels
import Persistence
import Repositories
@testable import Home

@MainActor
final class HomeStoreTests: XCTestCase {
    func test_initialState_hasNoWorkout() {
        let container = try! PulseModelContainer.inMemory()
        let store = HomeStore(workoutRepo: WorkoutRepository(modelContainer: container),
                              profileRepo: ProfileRepository(modelContainer: container))
        XCTAssertNil(store.todaysWorkout)
        XCTAssertNil(store.profile)
    }

    func test_refresh_loadsLatestWorkoutAndProfile() async throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        ctx.insert(ProfileEntity(
            id: UUID(), displayName: "Sam", goals: ["build muscle"],
            level: "regular", equipment: ["dumbbells"],
            frequencyPerWeek: 4, weeklyTargetMinutes: 180,
            activeCoachID: "rex", accentHue: 15, createdAt: Date()))
        ctx.insert(WorkoutEntity(
            id: UUID(), planID: UUID(), scheduledFor: Date(),
            title: "Push", subtitle: "Upper", workoutType: "Strength",
            durationMin: 45, status: "scheduled",
            blocksJSON: Data("[]".utf8), exercisesJSON: Data("[]".utf8),
            why: "Volume."))
        try ctx.save()
        let store = HomeStore(workoutRepo: WorkoutRepository(modelContainer: container),
                              profileRepo: ProfileRepository(modelContainer: container))
        await store.refresh()
        XCTAssertEqual(store.todaysWorkout?.title, "Push")
        XCTAssertEqual(store.profile?.displayName, "Sam")
    }

    func test_setWatchHKDenied_setsBannerVisible() {
        let suite = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let container = try! PulseModelContainer.inMemory()
        let store = HomeStore(workoutRepo: WorkoutRepository(modelContainer: container),
                              profileRepo: ProfileRepository(modelContainer: container),
                              defaults: defaults)
        XCTAssertFalse(store.watchHKDeniedBannerVisible)
        store.setWatchHKDenied()
        XCTAssertTrue(store.watchHKDeniedBannerVisible)
    }

    func test_dismissWatchHKBanner_clears() {
        let suite = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let container = try! PulseModelContainer.inMemory()
        let store = HomeStore(workoutRepo: WorkoutRepository(modelContainer: container),
                              profileRepo: ProfileRepository(modelContainer: container),
                              defaults: defaults)
        store.setWatchHKDenied()
        XCTAssertTrue(store.watchHKDeniedBannerVisible)
        store.dismissWatchHKBanner()
        XCTAssertFalse(store.watchHKDeniedBannerVisible)
    }
}
