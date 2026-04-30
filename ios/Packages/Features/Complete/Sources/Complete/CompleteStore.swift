import Foundation
import Observation
import CoreModels
import Persistence
import Repositories
import SwiftData

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
    public var adaptation: AdaptationPhase = .idle

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

public extension CompleteStore {
    typealias AdaptationStreamer = @MainActor () -> AsyncThrowingStream<AdaptationStreamEvent, Error>

    /// Submits feedback (idempotent), then streams adaptation. Retries once on
    /// failure; on second failure, calls fallback.
    @MainActor
    func runFlow(sessionID: UUID,
                 feedbackRepo: FeedbackRepository,
                 streamer: @escaping AdaptationStreamer,
                 fallback: @escaping @MainActor () -> Void,
                 nowProvider: @escaping () -> Date = Date.init) async {
        let feedback = WorkoutFeedback(
            sessionID: sessionID,
            submittedAt: nowProvider(),
            rating: feedbackDraft.rating,
            intensity: feedbackDraft.intensity,
            mood: feedbackDraft.mood,
            tags: Array(feedbackDraft.tags),
            exerciseRatings: feedbackDraft.exerciseRatings,
            note: feedbackDraft.note.isEmpty ? nil : feedbackDraft.note)
        do {
            try feedbackRepo.saveFeedback(feedback)
        } catch {
            adaptation = .failed(error)
            return
        }
        await goToAdaptationAndStream(streamer: streamer, fallback: fallback, attempt: 1)
    }

    @MainActor
    private func goToAdaptationAndStream(streamer: @escaping AdaptationStreamer,
                                         fallback: @escaping @MainActor () -> Void,
                                         attempt: Int) async {
        step = .adaptation
        adaptation = .streaming(checkpoints: [], adjustments: [],
                                rationale: nil, newWorkout: nil)
        do {
            for try await event in streamer() {
                apply(event)
                if case .done = adaptation { return }
            }
            throw NSError(domain: "Complete", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Stream ended early"])
        } catch {
            if attempt == 1 {
                await goToAdaptationAndStream(streamer: streamer,
                                              fallback: fallback,
                                              attempt: 2)
            } else {
                adaptation = .failed(error)
                fallback()
            }
        }
    }

    @MainActor
    private func apply(_ event: AdaptationStreamEvent) {
        guard case .streaming(var cps, var adjs, var rat, var wo) = adaptation else {
            if case .done = adaptation { return }
            adaptation = .streaming(checkpoints: [], adjustments: [],
                                    rationale: nil, newWorkout: nil)
            apply(event); return
        }
        switch event {
        case .checkpoint(let label):
            cps.append(label)
        case .textDelta:
            break
        case .adjustment(let a):
            adjs.append(a)
        case .workout(let w):
            wo = w
        case .rationale(let text):
            rat = text
        case .done(let payload, _, _, _):
            adaptation = .done(payload)
            return
        }
        adaptation = .streaming(checkpoints: cps, adjustments: adjs,
                                rationale: rat, newWorkout: wo)
    }
}
