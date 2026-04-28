import Foundation
import SwiftData

@Model
public final class FeedbackEntity {
    @Attribute(.unique) public var id: UUID
    public var userID: UUID?
    public var session: SessionEntity?
    public var submittedAt: Date
    public var rating: Int
    public var intensity: Int
    public var mood: String
    public var tags: [String]
    @Attribute(.externalStorage) public var exRatingsJSON: Data
    public var note: String?

    public init(id: UUID, userID: UUID? = nil, session: SessionEntity? = nil,
                submittedAt: Date, rating: Int, intensity: Int, mood: String,
                tags: [String], exRatingsJSON: Data, note: String? = nil) {
        self.id = id
        self.userID = userID
        self.session = session
        self.submittedAt = submittedAt
        self.rating = rating
        self.intensity = intensity
        self.mood = mood
        self.tags = tags
        self.exRatingsJSON = exRatingsJSON
        self.note = note
    }
}
