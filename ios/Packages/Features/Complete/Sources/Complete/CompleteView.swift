import SwiftUI
import SwiftData
import CoreModels
import DesignSystem
import Persistence
import Repositories
import HealthKitClient
import Networking

public struct CompleteView: View {
    @State private var store = CompleteStore()
    @State private var session: SessionEntity?
    @State private var workout: WorkoutEntity?
    @State private var nextWorkout: WorkoutEntity?
    @State private var setLogs: [SetLogEntity] = []
    @State private var firstFour: [(id: String, name: String)] = []
    @State private var didStartFlow = false

    private let sessionID: UUID
    private let modelContainer: ModelContainer
    private let api: APIClient
    private let healthKit: HealthKitClient
    private let manifestURL: URL
    private let coachName: String
    private let coach: Coach
    private let profile: Profile
    private let onDismiss: () -> Void

    public init(sessionID: UUID,
                modelContainer: ModelContainer,
                api: APIClient,
                healthKit: HealthKitClient,
                manifestURL: URL,
                coach: Coach,
                profile: Profile,
                onDismiss: @escaping () -> Void) {
        self.sessionID = sessionID
        self.modelContainer = modelContainer
        self.api = api
        self.healthKit = healthKit
        self.manifestURL = manifestURL
        self.coachName = coach.displayName
        self.coach = coach
        self.profile = profile
        self.onDismiss = onDismiss
    }

    public var body: some View {
        Group {
            switch store.step {
            case .recap:
                RecapStepView(session: session, workout: workout, setLogs: setLogs,
                              coachName: coachName) {
                    store.goToRate()
                }
            case .rate:
                RateStepView(store: store, coachName: coachName,
                             firstFourExercises: firstFour) {
                    await submit()
                }
            case .adaptation:
                AdaptationStepView(store: store, coachName: coachName, onDone: onDismiss)
            }
        }
        .task { await loadContext() }
    }

    @MainActor
    private func loadContext() async {
        let ctx = modelContainer.mainContext
        let sid = sessionID
        if let s = try? ctx.fetch(FetchDescriptor<SessionEntity>(
            predicate: #Predicate { $0.id == sid })).first {
            session = s
            let wid = s.workoutID
            workout = try? ctx.fetch(FetchDescriptor<WorkoutEntity>(
                predicate: #Predicate { $0.id == wid })).first
            setLogs = (try? ctx.fetch(FetchDescriptor<SetLogEntity>(
                predicate: #Predicate { $0.sessionID == sid }))) ?? []
        }
        if let w = workout,
           let blocks = try? JSONDecoder.pulse.decode([WorkoutBlock].self, from: w.blocksJSON) {
            firstFour = blocks.flatMap { $0.exercises }
                .prefix(4).map { (id: $0.exerciseID, name: $0.name) }
        }
        let nextDate = Calendar.current.date(byAdding: .day, value: 1,
                                             to: workout?.scheduledFor ?? Date()) ?? Date()
        let workoutRepo = WorkoutRepository(modelContainer: modelContainer)
        nextWorkout = try? workoutRepo.workoutForDate(nextDate)
    }

    @MainActor
    private func submit() async {
        guard !didStartFlow else { return }
        didStartFlow = true
        let feedbackRepo = FeedbackRepository(modelContainer: modelContainer)
        let adaptRepo = AdaptationRepository(modelContainer: modelContainer, api: api)

        guard let nextW = nextWorkout, let w = workout else {
            store.adaptation = .failed(NSError(domain: "Complete", code: -2,
                userInfo: [NSLocalizedDescriptionKey: "No next workout to adapt"]))
            return
        }

        let summaries = await healthKit.sevenDaySummary()
        let assetRepo = ExerciseAssetRepository(modelContainer: modelContainer,
                                                manifestURL: manifestURL)
        let availableExercises: [(id: String, name: String, equipment: [String])] =
            (try? assetRepo.allAssets())?.map {
                (id: $0.id, name: $0.name, equipment: $0.equipment)
            } ?? []
        let system = PromptBuilder.adaptationSystemPrompt(
            coach: coach, availableExercises: availableExercises)
        let userMsg = PromptBuilder.adaptationUserMessage(
            nextWorkout: nextW,
            justCompletedTitle: w.title,
            justCompletedDurationSec: session?.durationSec ?? 0,
            setLogs: setLogs,
            feedback: WorkoutFeedback(
                sessionID: sessionID,
                submittedAt: Date(),
                rating: store.feedbackDraft.rating,
                intensity: store.feedbackDraft.intensity,
                mood: store.feedbackDraft.mood,
                tags: Array(store.feedbackDraft.tags),
                exerciseRatings: store.feedbackDraft.exerciseRatings,
                note: store.feedbackDraft.note.isEmpty ? nil : store.feedbackDraft.note),
            profile: profile,
            summaries: summaries.isEmpty ? nil : summaries)

        let nextWID = nextW.id
        let appliedToPlanID = nextW.planID
        let feedbackID = UUID()
        let streamer: CompleteStore.AdaptationStreamer = {
            adaptRepo.streamAdaptation(
                systemPrompt: system,
                userMessage: userMsg,
                nextWorkoutID: nextWID,
                feedbackID: feedbackID,
                appliedToPlanID: appliedToPlanID)
        }
        let scheduledFor = nextW.scheduledFor
        let planID = nextW.planID
        let originalID = nextW.id
        let bundledFallback: @MainActor () -> Void = { [weak store, profile, modelContainer, api] in
            guard let store else { return }
            let plan = BundledFallback.todayWorkout(profile: profile, today: scheduledFor)
            guard let pw = plan.workouts.first else { return }
            let payload = AdaptationPayload(
                originalWorkoutID: originalID,
                newWorkout: pw,
                adjustments: [Adjustment(id: "fb1", label: "Steady today",
                                         detail: "Mobility-only — keeping things easy")],
                rationale: "Couldn't reach the planner; locking in a steady mobility day.")
            let repo = AdaptationRepository(modelContainer: modelContainer, api: api)
            try? repo.persist(payload: payload, feedbackID: feedbackID,
                              appliedToPlanID: planID,
                              modelUsed: "bundled-fallback",
                              promptTokens: 0, completionTokens: 0)
            store.adaptation = .done(payload)
        }
        await store.runFlow(sessionID: sessionID,
                            feedbackRepo: feedbackRepo,
                            streamer: streamer,
                            fallback: bundledFallback)
    }
}
