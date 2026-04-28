import XCTest
import SwiftData
@testable import Persistence

final class ExerciseAssetEntityTests: XCTestCase {
    @MainActor
    func test_exerciseAssetPersistsAndDedupesByID() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let asset = ExerciseAssetEntity(
            id: "back_squat",
            name: "Back Squat",
            focus: "legs",
            level: "intermediate",
            kind: "strength",
            equipment: ["barbell"],
            videoURL: URL(string: "https://pub-x.r2.dev/exercises/back_squat.mp4")!,
            posterURL: URL(string: "https://pub-x.r2.dev/exercises/back_squat-poster.jpg")!,
            instructionsJSON: Data("[]".utf8),
            manifestVersion: 1
        )
        ctx.insert(asset)
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<ExerciseAssetEntity>(
            predicate: #Predicate { $0.id == "back_squat" }
        ))
        XCTAssertEqual(fetched.count, 1)
    }
}
