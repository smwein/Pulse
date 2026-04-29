import Foundation
import SwiftData
import CoreModels
import Persistence

public enum FeedbackRepositoryError: Error, Equatable {
    case ratingMustBePositive
}

@MainActor
public final class FeedbackRepository {
    public let modelContainer: ModelContainer

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    public static func makeForTests(modelContainer: ModelContainer) -> FeedbackRepository {
        FeedbackRepository(modelContainer: modelContainer)
    }

    /// Idempotent on `feedback.sessionID` — calling twice updates the existing row.
    public func saveFeedback(_ feedback: WorkoutFeedback) throws {
        guard feedback.rating > 0 else { throw FeedbackRepositoryError.ratingMustBePositive }
        let ctx = modelContainer.mainContext
        try ctx.atomicWrite {
            let sid = feedback.sessionID
            let session = try ctx.fetch(FetchDescriptor<SessionEntity>(
                predicate: #Predicate { $0.id == sid })).first
            let exData = (try? JSONEncoder().encode(feedback.exerciseRatings)) ?? Data()
            // Look for an existing FeedbackEntity attached to the same session.
            let existing = try ctx.fetch(FetchDescriptor<FeedbackEntity>())
                .first(where: { $0.session?.id == sid })
            if let row = existing {
                row.submittedAt = feedback.submittedAt
                row.rating = feedback.rating
                row.intensity = feedback.intensity
                row.mood = feedback.mood.rawValue
                row.tags = feedback.tags
                row.exRatingsJSON = exData
                row.note = feedback.note
            } else {
                ctx.insert(FeedbackEntity(
                    id: UUID(),
                    session: session,
                    submittedAt: feedback.submittedAt,
                    rating: feedback.rating,
                    intensity: feedback.intensity,
                    mood: feedback.mood.rawValue,
                    tags: feedback.tags,
                    exRatingsJSON: exData,
                    note: feedback.note
                ))
            }
        }
    }
}
