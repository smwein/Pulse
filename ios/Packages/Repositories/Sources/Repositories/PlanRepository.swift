import Foundation
import SwiftData
import CoreModels
import Networking
import Persistence
import HealthKitClient
import Logging

@MainActor
public final class PlanRepository {
    public let modelContainer: ModelContainer
    private let api: APIClient?
    private let manifestURL: URL?

    public init(modelContainer: ModelContainer, api: APIClient, manifestURL: URL? = nil) {
        self.modelContainer = modelContainer
        self.api = api
        self.manifestURL = manifestURL
    }

    /// Test-only initializer. Bypasses APIClient — use only for read-side tests.
    public static func makeForTests(modelContainer: ModelContainer) -> PlanRepository {
        PlanRepository(modelContainer: modelContainer, api: nil, manifestURL: nil)
    }

    private init(modelContainer: ModelContainer, api: APIClient?, manifestURL: URL?) {
        self.modelContainer = modelContainer
        self.api = api
        self.manifestURL = manifestURL
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
                            let insertedIDs = try await persist(plan: plan, weekStart: weekStart,
                                                                modelUsed: modelUsed,
                                                                promptTokens: promptTokens,
                                                                completionTokens: completionTokens,
                                                                rawJSON: data)
                            continuation.yield(.done(plan, insertedWorkoutIDs: insertedIDs,
                                                     modelUsed: modelUsed,
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

    public static func _weekStart(for now: Date) -> Date {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
    }

    /// High-level wrapper. Builds prompts from profile + coach, then streams.
    public func streamFirstPlan(profile: Profile, coach: Coach,
                                now: Date = Date(),
                                summaries: SevenDayHealthSummary? = nil) -> AsyncThrowingStream<PlanStreamUpdate, Error> {
        let exercises = availableExercises(for: profile)
        let system = PromptBuilder.planGenSystemPrompt(coach: coach,
                                                      availableExercises: exercises)
        let user = PromptBuilder.planGenUserMessage(profile: profile, today: now, summaries: summaries)
        let weekStart = Self._weekStart(for: now)
        return generatePlan(systemPrompt: system, userMessage: user, weekStart: weekStart)
    }

    /// Same as `streamFirstPlan` but cascade-deletes the prior plan and all its
    /// workouts first. Cleanup is best-effort; plan generation still streams even
    /// if cleanup fails.
    public func regenerate(profile: Profile, coach: Coach,
                           now: Date = Date(),
                           summaries: SevenDayHealthSummary? = nil) -> AsyncThrowingStream<PlanStreamUpdate, Error> {
        let ctx = modelContainer.mainContext
        do {
            let priorPlans = try ctx.fetch(FetchDescriptor<PlanEntity>(
                sortBy: [SortDescriptor(\.generatedAt, order: .reverse)]))
            if let prior = priorPlans.first {
                let priorID = prior.id
                let priorWorkouts = try ctx.fetch(FetchDescriptor<WorkoutEntity>(
                    predicate: #Predicate { $0.planID == priorID }))
                for w in priorWorkouts { ctx.delete(w) }
                ctx.delete(prior)
                try ctx.save()
            }
        } catch {
            PulseLogger.repo.error("regenerate: best-effort prior-plan cleanup failed", error)
        }
        return streamFirstPlan(profile: profile, coach: coach, now: now, summaries: summaries)
    }

    // MARK: - Helpers

    /// Returns a sample of exercises filtered by the profile's equipment list.
    /// Limits to `PromptBuilder.maxCatalogEntries` entries so the system prompt
    /// stays compact. Falls back to the full (unfiltered) sample if the
    /// filtered set would be too thin.
    private func availableExercises(for profile: Profile) -> [(id: String, name: String, equipment: [String])] {
        // manifestURL is only used for fetching; we're reading the local DB here so any URL works.
        let url = manifestURL ?? URL(string: "https://placeholder.invalid/")!
        let assetRepo = ExerciseAssetRepository(modelContainer: modelContainer, manifestURL: url)
        guard let all = try? assetRepo.allAssets(), !all.isEmpty else { return [] }

        let userEquip = Set(profile.equipment.map { $0.lowercased() })
        let bodyOnly  = userEquip.contains("none") || userEquip.isEmpty

        // Filter: keep exercises whose equipment is body-only, or matches user's kit.
        let filtered = all.filter { asset in
            let assetEquip = asset.equipment.map { $0.lowercased() }
            if assetEquip.isEmpty { return true }           // body-weight always ok
            if bodyOnly           { return assetEquip.isEmpty || assetEquip == ["body only"] }
            return assetEquip.allSatisfy { userEquip.contains($0) || $0 == "body only" }
        }

        let pool = filtered.count >= 10 ? filtered : all   // fall back to full set if too thin
        let sample = pool.shuffled().prefix(PromptBuilder.maxCatalogEntries)
        return sample.map { (id: $0.id, name: $0.name, equipment: $0.equipment) }
    }

    private func persist(plan: WorkoutPlan, weekStart: Date, modelUsed: String,
                         promptTokens: Int, completionTokens: Int, rawJSON: Data) throws -> [UUID] {
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
        var inserted: [UUID] = []
        for pw in plan.workouts {
            let blocksJSON = (try? JSONEncoder.pulse.encode(pw.blocks)) ?? Data("[]".utf8)
            let exercisesFlat = pw.blocks.flatMap { $0.exercises }
            let exercisesJSON = (try? JSONEncoder.pulse.encode(exercisesFlat)) ?? Data("[]".utf8)
            let id = UUID()
            ctx.insert(WorkoutEntity(
                id: id,
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
            inserted.append(id)
        }
        try ctx.save()
        return inserted
    }

    /// Test-only — exposes `persist` for unit tests of the fan-out logic.
    @discardableResult
    public func _persistForTests(plan: WorkoutPlan, weekStart: Date,
                                 modelUsed: String, promptTokens: Int,
                                 completionTokens: Int, rawJSON: Data) throws -> [UUID] {
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
