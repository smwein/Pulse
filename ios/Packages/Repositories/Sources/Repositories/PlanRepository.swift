import Foundation
import SwiftData
import CoreModels
import Networking
import Persistence

@MainActor
public final class PlanRepository {
    public let modelContainer: ModelContainer
    private let api: APIClient?

    public init(modelContainer: ModelContainer, api: APIClient) {
        self.modelContainer = modelContainer
        self.api = api
    }

    /// Test-only initializer. Bypasses APIClient — use only for read-side tests.
    public static func makeForTests(modelContainer: ModelContainer) -> PlanRepository {
        PlanRepository(modelContainer: modelContainer, api: nil)
    }

    private init(modelContainer: ModelContainer, api: APIClient?) {
        self.modelContainer = modelContainer
        self.api = api
    }

    public func listLatest(limit: Int = 5) throws -> [PlanEntity] {
        var descriptor = FetchDescriptor<PlanEntity>(
            sortBy: [SortDescriptor(\.generatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try modelContainer.mainContext.fetch(descriptor)
    }

    /// Streams a plan generation, yielding incremental updates. The final `.done`
    /// case carries the parsed plan; the repository persists it before yielding.
    public func generatePlan(systemPrompt: String, userMessage: String,
                             weekStart: Date) -> AsyncThrowingStream<PlanStreamUpdate, Error> {
        guard let api else {
            return AsyncThrowingStream { $0.finish(throwing: APIClientError.badStatus(0)) }
        }
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = AnthropicRequest.planGeneration(
                        systemPrompt: systemPrompt,
                        userMessage: userMessage
                    )
                    var fullText = ""
                    var modelUsed = "claude-opus-4-7"
                    var promptTokens = 0
                    var completionTokens = 0
                    var checkpoints = CheckpointExtractor()

                    for try await event in api.streamEvents(request: request) {
                        switch event.event {
                        case "message_start":
                            if let dict = try? JSONSerialization.jsonObject(with: Data(event.data.utf8)) as? [String: Any],
                               let msg = dict["message"] as? [String: Any] {
                                if let m = msg["model"] as? String { modelUsed = m }
                            }
                        case "content_block_delta":
                            if let text = Self.extractTextDelta(eventData: event.data) {
                                fullText.append(text)
                                let result = checkpoints.feed(text)
                                for cp in result.checkpoints {
                                    continuation.yield(.checkpoint(cp))
                                }
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
                                throw APIClientError.decoding("no fenced ```json block in stream")
                            }
                            let plan = try JSONDecoder.pulse.decode(WorkoutPlan.self, from: data)
                            try await persist(plan: plan, weekStart: weekStart, modelUsed: modelUsed,
                                              promptTokens: promptTokens, completionTokens: completionTokens,
                                              rawJSON: data)
                            continuation.yield(.done(plan, modelUsed: modelUsed,
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

    private func persist(plan: WorkoutPlan, weekStart: Date, modelUsed: String,
                         promptTokens: Int, completionTokens: Int, rawJSON: Data) throws {
        let planEntity = PlanEntity(
            id: UUID(),
            weekStart: weekStart,
            generatedAt: Date(),
            modelUsed: modelUsed,
            promptTokens: promptTokens,
            completionTokens: completionTokens,
            payloadJSON: rawJSON
        )
        let ctx = modelContainer.mainContext
        ctx.insert(planEntity)
        for pw in plan.workouts {
            let blocksJSON = (try? JSONEncoder.pulse.encode(pw.blocks)) ?? Data("[]".utf8)
            let exercisesFlat = pw.blocks.flatMap { $0.exercises }
            let exercisesJSON = (try? JSONEncoder.pulse.encode(exercisesFlat)) ?? Data("[]".utf8)
            ctx.insert(WorkoutEntity(
                id: UUID(),
                planID: planEntity.id,
                scheduledFor: pw.scheduledFor,
                title: pw.title,
                subtitle: pw.subtitle,
                workoutType: pw.workoutType,
                durationMin: pw.durationMin,
                status: "scheduled",
                blocksJSON: blocksJSON,
                exercisesJSON: exercisesJSON,
                why: pw.why
            ))
        }
        try ctx.save()
    }

    /// Test-only — exposes `persist` for unit tests of the fan-out logic.
    public func _persistForTests(plan: WorkoutPlan, weekStart: Date,
                                 modelUsed: String, promptTokens: Int,
                                 completionTokens: Int, rawJSON: Data) throws {
        try persist(plan: plan, weekStart: weekStart, modelUsed: modelUsed,
                    promptTokens: promptTokens, completionTokens: completionTokens,
                    rawJSON: rawJSON)
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
