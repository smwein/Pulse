import Foundation
import SwiftData
import CoreModels
import Networking
import Persistence

public enum AdaptationStreamUpdate: Sendable {
    case checkpoint(String)
    case textDelta(String)
    case done(AdaptationDiff, modelUsed: String, promptTokens: Int, completionTokens: Int)
}

@MainActor
public final class FeedbackRepository {
    public let modelContainer: ModelContainer
    private let api: APIClient?

    public init(modelContainer: ModelContainer, api: APIClient) {
        self.modelContainer = modelContainer
        self.api = api
    }

    public static func makeForTests(modelContainer: ModelContainer) -> FeedbackRepository {
        FeedbackRepository(modelContainer: modelContainer, api: nil)
    }

    private init(modelContainer: ModelContainer, api: APIClient?) {
        self.modelContainer = modelContainer
        self.api = api
    }

    public func saveFeedback(_ feedback: WorkoutFeedback) throws {
        let ctx = modelContainer.mainContext
        let sessionID = feedback.sessionID
        let sessionDescriptor = FetchDescriptor<SessionEntity>(
            predicate: #Predicate { $0.id == sessionID }
        )
        let session = try ctx.fetch(sessionDescriptor).first

        let exData = (try? JSONEncoder().encode(feedback.exerciseRatings)) ?? Data()
        let entity = FeedbackEntity(
            id: UUID(),
            session: session,
            submittedAt: feedback.submittedAt,
            rating: feedback.rating,
            intensity: feedback.intensity,
            mood: feedback.mood.rawValue,
            tags: feedback.tags,
            exRatingsJSON: exData,
            note: feedback.note
        )
        ctx.insert(entity)
        try ctx.save()
    }

    /// Streams an adaptation request. The final `.done` carries the parsed diff;
    /// the repository persists an AdaptationEntity before yielding.
    public func adaptPlan(systemPrompt: String,
                          priorPlanJSON: String,
                          feedbackJSON: String,
                          appliedToPlanID: UUID,
                          feedbackID: UUID) -> AsyncThrowingStream<AdaptationStreamUpdate, Error> {
        guard let api else {
            return AsyncThrowingStream { $0.finish(throwing: APIClientError.badStatus(0)) }
        }
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let user = """
                    Prior plan:
                    \(priorPlanJSON)

                    Latest workout feedback:
                    \(feedbackJSON)

                    Produce an updated plan + diff.
                    """
                    let request = AnthropicRequest.adaptation(
                        systemPrompt: systemPrompt,
                        userMessage: user
                    )
                    var fullText = ""
                    var modelUsed = "claude-opus-4-7"
                    var promptTokens = 0
                    var completionTokens = 0
                    var checkpoints = CheckpointExtractor()

                    for try await event in api.streamEvents(request: request) {
                        switch event.event {
                        case "content_block_delta":
                            if let text = Self.extractTextDelta(eventData: event.data) {
                                fullText.append(text)
                                let result = checkpoints.feed(text)
                                for cp in result.checkpoints { continuation.yield(.checkpoint(cp)) }
                                if !result.passthroughText.isEmpty {
                                    continuation.yield(.textDelta(result.passthroughText))
                                }
                            }
                        case "message_delta":
                            if let dict = try? JSONSerialization.jsonObject(with: Data(event.data.utf8)) as? [String: Any],
                               let usage = dict["usage"] as? [String: Any] {
                                if let p = usage["input_tokens"] as? Int { promptTokens = p }
                                if let c = usage["output_tokens"] as? Int { completionTokens = c }
                            }
                        case "message_stop":
                            guard let json = JSONBlockExtractor.extract(from: fullText),
                                  let data = json.data(using: .utf8) else {
                                throw APIClientError.decoding("no fenced ```json block")
                            }
                            let diff = try JSONDecoder.pulse.decode(AdaptationDiff.self, from: data)
                            try await persist(diff: diff, feedbackID: feedbackID, planID: appliedToPlanID,
                                              modelUsed: modelUsed, promptTokens: promptTokens,
                                              completionTokens: completionTokens, rawJSON: data)
                            continuation.yield(.done(diff, modelUsed: modelUsed,
                                                     promptTokens: promptTokens,
                                                     completionTokens: completionTokens))
                            continuation.finish()
                            return
                        default: break
                        }
                    }
                    throw APIClientError.decoding("stream ended without message_stop")
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func persist(diff: AdaptationDiff, feedbackID: UUID, planID: UUID,
                         modelUsed: String, promptTokens: Int, completionTokens: Int,
                         rawJSON: Data) throws {
        let entity = AdaptationEntity(
            id: UUID(),
            feedbackID: feedbackID,
            appliedToPlanID: planID,
            generatedAt: Date(),
            modelUsed: modelUsed,
            promptTokens: promptTokens,
            completionTokens: completionTokens,
            diffJSON: rawJSON,
            rationale: diff.rationale
        )
        let ctx = modelContainer.mainContext
        ctx.insert(entity)
        try ctx.save()
    }

    private static func extractTextDelta(eventData: String) -> String? {
        guard let data = eventData.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let delta = dict["delta"] as? [String: Any],
              delta["type"] as? String == "text_delta",
              let text = delta["text"] as? String else { return nil }
        return text
    }
}
