import XCTest
import SwiftData
import Persistence
@testable import Repositories

final class ExerciseAssetRepositoryTests: XCTestCase {
    @MainActor
    func test_loadManifestPersistsAllAssets() async throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "manifest-sample", withExtension: "json", subdirectory: "Fixtures"))
        let data = try Data(contentsOf: url)
        let container = try PulseModelContainer.inMemory()
        let repo = ExerciseAssetRepository(modelContainer: container,
                                           manifestURL: URL(string: "https://example.test/m.json")!,
                                           fetcher: { _ in data })
        try await repo.refreshFromManifest()
        let all = try repo.allAssets()
        XCTAssertEqual(all.count, 2)
        let squat = repo.lookup(id: "Back_Squat")
        XCTAssertEqual(squat?.name, "Back Squat")
        XCTAssertEqual(squat?.focus, "strength")
        XCTAssertEqual(squat?.kind, "strength")
        XCTAssertEqual(squat?.equipment, ["barbell"])
        let stretch = repo.lookup(id: "World_Greatest_Stretch")
        XCTAssertEqual(stretch?.kind, "mobility")
        XCTAssertEqual(stretch?.equipment, [])
    }

    @MainActor
    func test_refreshIsIdempotent_doesNotDuplicate() async throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "manifest-sample", withExtension: "json", subdirectory: "Fixtures"))
        let data = try Data(contentsOf: url)
        let container = try PulseModelContainer.inMemory()
        let repo = ExerciseAssetRepository(modelContainer: container,
                                           manifestURL: URL(string: "https://example.test/m.json")!,
                                           fetcher: { _ in data })
        try await repo.refreshFromManifest()
        try await repo.refreshFromManifest()
        XCTAssertEqual(try repo.allAssets().count, 2)
    }
}
