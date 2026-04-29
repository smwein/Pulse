import XCTest
import CoreModels
@testable import Repositories

final class BundledFallbackTests: XCTestCase {
    func test_todayWorkout_decodesBackToWorkoutPlan() throws {
        let plan = BundledFallback.todayWorkout(
            profile: ProfileRepositoryTests.fixtureProfile(),
            today: Date(timeIntervalSince1970: 1_730_000_000))
        let data = try JSONEncoder.pulse.encode(plan)
        let round = try JSONDecoder.pulse.decode(WorkoutPlan.self, from: data)
        XCTAssertEqual(round.workouts.count, 1)
        XCTAssertEqual(round.workouts.first?.workoutType, "Mobility")
    }

    func test_everyExerciseIDExistsInCatalogManifest() throws {
        let url = Bundle.module.url(forResource: "CatalogManifest", withExtension: "json", subdirectory: "Fixtures")
        let data = try Data(contentsOf: XCTUnwrap(url))
        struct Row: Decodable { let id: String }
        let rows = try JSONDecoder().decode([Row].self, from: data)
        let known = Set(rows.map(\.id))
        for id in BundledFallback.exerciseIDs {
            XCTAssertTrue(known.contains(id), "Bundled fallback uses unknown exercise id: \(id)")
        }
    }
}
