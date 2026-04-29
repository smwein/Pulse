import Foundation
import SwiftData
import CoreModels
import Networking
import Persistence

@MainActor
public final class AdaptationRepository {
    public let modelContainer: ModelContainer
    private let api: APIClient?

    public init(modelContainer: ModelContainer, api: APIClient) {
        self.modelContainer = modelContainer
        self.api = api
    }

    public static func makeForTests(modelContainer: ModelContainer) -> AdaptationRepository {
        AdaptationRepository(modelContainer: modelContainer, api: nil)
    }

    private init(modelContainer: ModelContainer, api: APIClient?) {
        self.modelContainer = modelContainer
        self.api = api
    }

    /// Streams an adaptation request. Yields adjustment/workout/rationale events
    /// as labeled fences appear in the assembled text, then `done` after persistence.
    public func streamAdaptation(
        systemPrompt: String,
        userMessage: String,
        nextWorkoutID: UUID,
        feedbackID: UUID,
        appliedToPlanID: UUID
    ) -> AsyncThrowingStream<AdaptationStreamEvent, Error> {
        guard let api else {
            return AsyncThrowingStream { $0.finish(throwing: APIClientError.badStatus(0)) }
        }
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = AnthropicRequest.adaptation(
                        systemPrompt: systemPrompt,
                        userMessage: userMessage)
                    var fullText = ""
                    var modelUsed = "claude-opus-4-7"
                    var promptTokens = 0
                    var completionTokens = 0
                    var checkpoints = CheckpointExtractor()
                    var emittedAdjustmentIDs: Set<String> = []
                    var emittedWorkout = false
                    var emittedRationale: String?

                    for try await event in api.streamEvents(request: request) {
                        switch event.event {
                        case "message_start":
                            if let dict = try? JSONSerialization.jsonObject(with: Data(event.data.utf8)) as? [String: Any],
                               let msg = dict["message"] as? [String: Any],
                               let m = msg["model"] as? String { modelUsed = m }
                        case "content_block_delta":
                            if let text = Self.extractTextDelta(eventData: event.data) {
                                fullText.append(text)
                                let result = checkpoints.feed(text)
                                for cp in result.checkpoints { continuation.yield(.checkpoint(cp)) }
                                if !result.passthroughText.isEmpty {
                                    continuation.yield(.textDelta(result.passthroughText))
                                }
                                // Emit any newly-completed labeled blocks.
                                for block in JSONBlockExtractor.extractAllLabeled(from: fullText) {
                                    switch block.label {
                                    case "adjustment":
                                        if let data = block.body.data(using: .utf8),
                                           let adj = try? JSONDecoder.pulse.decode(Adjustment.self, from: data),
                                           !emittedAdjustmentIDs.contains(adj.id) {
                                            emittedAdjustmentIDs.insert(adj.id)
                                            continuation.yield(.adjustment(adj))
                                        }
                                    case "workout":
                                        if !emittedWorkout,
                                           let data = block.body.data(using: .utf8),
                                           let pw = try? JSONDecoder.pulse.decode(PlannedWorkout.self, from: data) {
                                            emittedWorkout = true
                                            continuation.yield(.workout(pw))
                                        }
                                    case "rationale":
                                        if emittedRationale == nil,
                                           let data = block.body.data(using: .utf8),
                                           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                                           let text = dict["text"] as? String {
                                            emittedRationale = text
                                            continuation.yield(.rationale(text))
                                        }
                                    default:
                                        break
                                    }
                                }
                            }
                        case "message_delta":
                            if let dict = try? JSONSerialization.jsonObject(with: Data(event.data.utf8)) as? [String: Any],
                               let usage = dict["usage"] as? [String: Any] {
                                if let p = usage["input_tokens"] as? Int { promptTokens = p }
                                if let c = usage["output_tokens"] as? Int { completionTokens = c }
                            }
                        case "message_stop":
                            // Final reconciliation.
                            let finalBlocks = JSONBlockExtractor.extractAllLabeled(from: fullText)
                            guard let workoutBlock = finalBlocks.first(where: { $0.label == "workout" }),
                                  let workoutData = workoutBlock.body.data(using: .utf8),
                                  let newWorkout = try? JSONDecoder.pulse.decode(PlannedWorkout.self, from: workoutData) else {
                                throw APIClientError.decoding("missing or malformed workout block")
                            }
                            let adjustments: [Adjustment] = finalBlocks
                                .filter { $0.label == "adjustment" }
                                .compactMap {
                                    guard let d = $0.body.data(using: .utf8) else { return nil }
                                    return try? JSONDecoder.pulse.decode(Adjustment.self, from: d)
                                }
                            let rationale: String = finalBlocks
                                .first(where: { $0.label == "rationale" })
                                .flatMap { b -> String? in
                                    guard let d = b.body.data(using: .utf8),
                                          let dict = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return nil }
                                    return dict["text"] as? String
                                } ?? ""
                            let payload = AdaptationPayload(
                                originalWorkoutID: nextWorkoutID,
                                newWorkout: newWorkout,
                                adjustments: adjustments,
                                rationale: rationale)
                            try persist(payload: payload,
                                        feedbackID: feedbackID,
                                        appliedToPlanID: appliedToPlanID,
                                        modelUsed: modelUsed,
                                        promptTokens: promptTokens,
                                        completionTokens: completionTokens)
                            continuation.yield(.done(payload, modelUsed: modelUsed,
                                                     promptTokens: promptTokens,
                                                     completionTokens: completionTokens))
                            continuation.finish()
                            return
                        default:
                            break
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

    /// Inserts the new WorkoutEntity, marks the original superseded, persists the AdaptationEntity.
    /// All three writes in a single atomic-write transaction.
    public func persist(payload: AdaptationPayload,
                        feedbackID: UUID,
                        appliedToPlanID: UUID,
                        modelUsed: String,
                        promptTokens: Int,
                        completionTokens: Int) throws {
        let ctx = modelContainer.mainContext
        try ctx.atomicWrite {
            let originalID = payload.originalWorkoutID
            guard let original = try ctx.fetch(FetchDescriptor<WorkoutEntity>(
                predicate: #Predicate { $0.id == originalID })).first else {
                throw AdaptationRepositoryError.originalWorkoutNotFound(originalID)
            }
            original.status = "superseded"

            let pw = payload.newWorkout
            let blocksJSON = (try? JSONEncoder.pulse.encode(pw.blocks)) ?? Data("[]".utf8)
            let exercisesFlat = pw.blocks.flatMap { $0.exercises }
            let exercisesJSON = (try? JSONEncoder.pulse.encode(exercisesFlat)) ?? Data("[]".utf8)
            ctx.insert(WorkoutEntity(
                id: UUID(), planID: original.planID,
                scheduledFor: pw.scheduledFor,
                title: pw.title, subtitle: pw.subtitle,
                workoutType: pw.workoutType, durationMin: pw.durationMin,
                status: "scheduled",
                blocksJSON: blocksJSON, exercisesJSON: exercisesJSON,
                why: pw.why))

            let payloadData = (try? JSONEncoder.pulse.encode(payload)) ?? Data()
            ctx.insert(AdaptationEntity(
                id: UUID(),
                feedbackID: feedbackID,
                appliedToPlanID: appliedToPlanID,
                generatedAt: Date(),
                modelUsed: modelUsed,
                promptTokens: promptTokens,
                completionTokens: completionTokens,
                diffJSON: payloadData,
                rationale: payload.rationale))
        }
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

public enum AdaptationRepositoryError: Error, Equatable {
    case originalWorkoutNotFound(UUID)
}
