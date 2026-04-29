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

    @MainActor
    func test_saveFeedback_isIdempotentOnSessionID() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let session = SessionEntity(id: UUID(), workoutID: UUID(), startedAt: Date())
        ctx.insert(session); try ctx.save()
        let repo = FeedbackRepository.makeForTests(modelContainer: container)
        let fb = WorkoutFeedback(sessionID: session.id, submittedAt: Date(),
            rating: 3, intensity: 3, mood: .good, tags: [],
            exerciseRatings: [:], note: nil)
        try repo.saveFeedback(fb)
        var fb2 = fb
        fb2.rating = 5
        try repo.saveFeedback(fb2)
        let rows = try ctx.fetch(FetchDescriptor<FeedbackEntity>())
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.rating, 5)
    }

    @MainActor
    func test_saveFeedback_throwsOnRatingZero() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let session = SessionEntity(id: UUID(), workoutID: UUID(), startedAt: Date())
        ctx.insert(session); try ctx.save()
        let repo = FeedbackRepository.makeForTests(modelContainer: container)
        let fb = WorkoutFeedback(sessionID: session.id, submittedAt: Date(),
            rating: 0, intensity: 3, mood: .good, tags: [],
            exerciseRatings: [:], note: nil)
        XCTAssertThrowsError(try repo.saveFeedback(fb))
    }
}
