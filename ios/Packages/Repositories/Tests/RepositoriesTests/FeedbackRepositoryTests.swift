import XCTest
import SwiftData
import CoreModels
import Persistence
@testable import Repositories

final class FeedbackRepositoryTests: XCTestCase {
    @MainActor
    func test_saveFeedbackPersistsAndAttachesToSession() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let session = SessionEntity(id: UUID(), workoutID: UUID(), startedAt: Date())
        ctx.insert(session); try ctx.save()

        let repo = FeedbackRepository.makeForTests(modelContainer: container)
        let fb = WorkoutFeedback(
            sessionID: session.id,
            submittedAt: Date(),
            rating: 4,
            intensity: 3,
            mood: .good,
            tags: ["energized"],
            exerciseRatings: ["back_squat": .up],
            note: nil
        )
        try repo.saveFeedback(fb)

        let fetched = try ctx.fetch(FetchDescriptor<FeedbackEntity>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.session?.id, session.id)
    }
}
