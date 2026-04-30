import Foundation
import Observation
import CoreModels

@MainActor
@Observable
public final class CompleteStore {
    public enum Step: Sendable { case recap, rate, adaptation }
    public enum AdaptationPhase: Sendable {
        case idle
        case streaming(checkpoints: [String], adjustments: [Adjustment], rationale: String?, newWorkout: PlannedWorkout?)
        case done(AdaptationPayload)
        case failed(Error)
    }

    public private(set) var step: Step = .recap
    public var feedbackDraft: FeedbackDraft = FeedbackDraft()
    public private(set) var adaptation: AdaptationPhase = .idle

    public init() {}

    public func goToRate() { step = .rate }
    public func goToAdaptation() { step = .adaptation }

    public struct FeedbackDraft: Sendable, Equatable {
        public var rating: Int = 0
        public var intensity: Int = 0
        public var mood: WorkoutFeedback.Mood = .ok
        public var tags: Set<String> = []
        public var exerciseRatings: [String: WorkoutFeedback.ExerciseRating] = [:]
        public var note: String = ""

        public init() {}
        public var canSubmit: Bool { rating > 0 }
    }
}
