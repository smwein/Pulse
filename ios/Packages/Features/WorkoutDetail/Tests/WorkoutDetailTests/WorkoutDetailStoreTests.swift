import XCTest
import SwiftData
import CoreModels
import Persistence
import Repositories
@testable import WorkoutDetail

@MainActor
final class WorkoutDetailStoreTests: XCTestCase {
    private func makeAssetRepo(_ container: ModelContainer) -> ExerciseAssetRepository {
        // Manifest URL is unused in tests since lookup() reads from SwiftData
        ExerciseAssetRepository(
            modelContainer: container,
            manifestURL: URL(string: "https://example.com/manifest.json")!
        )
    }

    func test_loadResolvesWorkoutAndAssets() async throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext

        let blocksJSON = #"""
        [{"id":"b1","label":"Main","exercises":[{"id":"e1","exerciseID":"asset-001","name":"Push-up","sets":[{"setNum":1,"reps":10,"load":"BW","restSec":60}]}]}]
        """#.data(using: .utf8)!
        let id = UUID()
        ctx.insert(WorkoutEntity(
            id: id, planID: UUID(), scheduledFor: Date(),
            title: "Push", subtitle: "Upper", workoutType: "Strength",
            durationMin: 45, status: "scheduled",
            blocksJSON: blocksJSON, exercisesJSON: Data("[]".utf8), why: "Volume."))
        ctx.insert(ExerciseAssetEntity(
            id: "asset-001", name: "Push-up", focus: "chest", level: "beginner",
            kind: "compound", equipment: ["bodyweight"],
            videoURL: URL(string: "https://example.com/asset-001.mp4")!,
            posterURL: URL(string: "https://example.com/asset-001.jpg")!,
            instructionsJSON: Data("[]".utf8), manifestVersion: 1))
        try ctx.save()

        let store = WorkoutDetailStore(
            workoutID: id,
            modelContainer: container,
            assetRepo: makeAssetRepo(container)
        )
        await store.load()
        XCTAssertEqual(store.workoutTitle, "Push")
        XCTAssertEqual(store.blocks.count, 1)
        XCTAssertEqual(store.blocks.first?.exercises.first?.name, "Push-up")
        XCTAssertNotNil(store.asset(for: "asset-001"))
    }

    func test_assetMiss_returnsNil() async throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let blocksJSON = #"""
        [{"id":"b1","label":"Main","exercises":[{"id":"e1","exerciseID":"unknown","name":"Mystery","sets":[]}]}]
        """#.data(using: .utf8)!
        let id = UUID()
        ctx.insert(WorkoutEntity(
            id: id, planID: UUID(), scheduledFor: Date(),
            title: "T", subtitle: "", workoutType: "Strength", durationMin: 30,
            status: "scheduled",
            blocksJSON: blocksJSON, exercisesJSON: Data("[]".utf8), why: nil))
        try ctx.save()
        let store = WorkoutDetailStore(
            workoutID: id,
            modelContainer: container,
            assetRepo: makeAssetRepo(container)
        )
        await store.load()
        XCTAssertNil(store.asset(for: "unknown"))
    }
}
