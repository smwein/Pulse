import Foundation

public struct WorkoutFeedback: Codable, Hashable, Sendable {
    public enum Mood: String, Codable, Hashable, Sendable {
        case great, good, ok, rough
    }

    public enum ExerciseRating: String, Codable, Hashable, Sendable {
        case up, down
    }

    public var sessionID: UUID
    public var submittedAt: Date
    public var rating: Int                              // 1...5
    public var intensity: Int                           // 1...5
    public var mood: Mood
    public var tags: [String]
    public var exerciseRatings: [String: ExerciseRating]   // [exerciseID: up|down]
    public var note: String?

    public init(sessionID: UUID, submittedAt: Date, rating: Int, intensity: Int,
                mood: Mood, tags: [String],
                exerciseRatings: [String: ExerciseRating], note: String?) {
        self.sessionID = sessionID
        self.submittedAt = submittedAt
        self.rating = rating
        self.intensity = intensity
        self.mood = mood
        self.tags = tags
        self.exerciseRatings = exerciseRatings
        self.note = note
    }
}
