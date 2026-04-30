import SwiftUI
import SwiftData
import CoreModels
import DesignSystem
import Persistence
import Repositories
import Onboarding
import Home
import PlanGeneration
import WorkoutDetail
import InWorkout
import Complete

struct DebugFeatureSmokeView: View {
    let appContainer: AppContainer
    let themeStore: ThemeStore

    @State private var route: Route?

    private enum Route: Identifiable, Hashable {
        case onboarding
        case planGen
        case home
        case workoutDetail(UUID)
        case inWorkout(UUID)
        case complete(UUID)
        var id: String {
            switch self {
            case .onboarding: return "onboarding"
            case .planGen: return "planGen"
            case .home: return "home"
            case .workoutDetail(let id): return "wd-\(id)"
            case .inWorkout(let id):     return "iw-\(id)"
            case .complete(let id):      return "cp-\(id)"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: PulseSpacing.md) {
                button("Run Onboarding") { route = .onboarding }
                button("Run PlanGeneration (with seeded profile)") {
                    seedProfileIfMissing()
                    route = .planGen
                }
                button("Run Home (with seeded profile + workout)") {
                    seedProfileIfMissing()
                    seedWorkoutIfMissing()
                    route = .home
                }
                button("Run WorkoutDetail (latest)") {
                    seedProfileIfMissing()
                    seedWorkoutIfMissing()
                    if let w = (try? WorkoutRepository(modelContainer: appContainer.modelContainer).latestWorkout()) {
                        route = .workoutDetail(w.id)
                    }
                }
                button("Run InWorkout (latest workout)") {
                    seedProfileIfMissing()
                    seedWorkoutIfMissing()
                    if let w = (try? WorkoutRepository(modelContainer: appContainer.modelContainer).latestWorkout()) {
                        route = .inWorkout(w.id)
                    }
                }
                button("Run Complete (latest session)") {
                    let ctx = appContainer.modelContainer.mainContext
                    if let s = (try? ctx.fetch(FetchDescriptor<SessionEntity>()))?.first {
                        route = .complete(s.id)
                    }
                }
                Divider()
                button("Wipe Profile + Workouts (reset first-run)") { wipe() }
            }
            .padding(PulseSpacing.lg)
        }
        #if os(iOS)
        .fullScreenCover(item: $route) { r in routeView(r) }
        #endif
    }

    @ViewBuilder
    private func routeView(_ r: Route) -> some View {
        switch r {
        case .onboarding:
            let profileRepo = ProfileRepository(modelContainer: appContainer.modelContainer)
            OnboardingFlowView(profileRepo: profileRepo, themeStore: themeStore) { _ in
                await MainActor.run { route = nil }
            }
        case .planGen:
            planGenView()
        case .home:
            NavigationStack {
                HomeView(
                    workoutRepo: WorkoutRepository(modelContainer: appContainer.modelContainer),
                    profileRepo: ProfileRepository(modelContainer: appContainer.modelContainer),
                    onViewWorkout: { id in route = .workoutDetail(id) },
                    onRegenerate: { route = .planGen }
                )
            }
        case .workoutDetail(let id):
            WorkoutDetailView(
                workoutID: id,
                modelContainer: appContainer.modelContainer,
                assetRepo: ExerciseAssetRepository(
                    modelContainer: appContainer.modelContainer,
                    manifestURL: appContainer.manifestURL
                )
            )
        case .inWorkout(let wid):
            let workoutRepo = WorkoutRepository(modelContainer: appContainer.modelContainer)
            let workout = (try? workoutRepo.workoutForID(wid)) ?? nil
            let flat = workout.map { SessionStore.flatten(workout: $0) } ?? []
            let assetRepo = ExerciseAssetRepository(
                modelContainer: appContainer.modelContainer,
                manifestURL: appContainer.manifestURL)
            InWorkoutView(
                workoutID: wid,
                modelContainer: appContainer.modelContainer,
                flat: flat,
                assetRepo: assetRepo,
                onComplete: { sid in route = .complete(sid) },
                onDiscard: { route = nil })
        case .complete(let sid):
            let profileRepo = ProfileRepository(modelContainer: appContainer.modelContainer)
            if let p = profileRepo.currentProfile(),
               let coach = Coach.byID(p.activeCoachID) {
                CompleteView(sessionID: sid,
                             modelContainer: appContainer.modelContainer,
                             api: appContainer.api,
                             healthKit: appContainer.healthKit,
                             manifestURL: appContainer.manifestURL,
                             coach: coach,
                             profile: p,
                             onDismiss: { route = nil })
            }
        }
    }

    @ViewBuilder
    private func planGenView() -> some View {
        let profileRepo = ProfileRepository(modelContainer: appContainer.modelContainer)
        if let profile = profileRepo.currentProfile(),
           let coach = Coach.byID(profile.activeCoachID) {
            let planRepo = PlanRepository(modelContainer: appContainer.modelContainer, api: appContainer.api,
                                          manifestURL: appContainer.manifestURL)
            PlanGenerationView(
                profile: profile, coach: coach, mode: .firstPlan,
                streamProvider: { p in planRepo.streamFirstPlan(profile: p, coach: coach) },
                onPersistedWorkout: { _, ids in
                    if let id = ids.first {
                        let repo = WorkoutRepository(modelContainer: appContainer.modelContainer)
                        let title = (try? repo.latestWorkout())?.title ?? "Today's workout"
                        return DebugWorkoutHandle(id: id, title: title)
                    }
                    return nil
                },
                onViewWorkout: { id in route = .workoutDetail(id) },
                onBackToHome: { route = nil }
            )
        }
    }

    private func button(_ title: String, action: @escaping () -> Void) -> some View {
        PulseButton(title, variant: .ghost, action: action)
    }

    private func seedProfileIfMissing() {
        let repo = ProfileRepository(modelContainer: appContainer.modelContainer)
        guard repo.currentProfile() == nil else { return }
        let p = Profile(id: UUID(), displayName: "DebugUser",
                        goals: ["build muscle"], level: .regular,
                        equipment: ["dumbbells"], frequencyPerWeek: 4,
                        weeklyTargetMinutes: 180, activeCoachID: "rex",
                        createdAt: Date())
        try? repo.save(p)
    }

    @MainActor
    private func seedWorkoutIfMissing() {
        let repo = WorkoutRepository(modelContainer: appContainer.modelContainer)
        if (try? repo.latestWorkout()) != nil { return }
        let ctx = appContainer.modelContainer.mainContext
        ctx.insert(WorkoutEntity(
            id: UUID(), planID: UUID(), scheduledFor: Date(),
            title: "Sample Push", subtitle: "Upper body smoke",
            workoutType: "Strength", durationMin: 45, status: "scheduled",
            blocksJSON: Data("[]".utf8), exercisesJSON: Data("[]".utf8),
            why: "Seeded by DebugFeatureSmokeView."))
        try? ctx.save()
    }

    @MainActor
    private func wipe() {
        let ctx = appContainer.modelContainer.mainContext
        for p in (try? ctx.fetch(FetchDescriptor<ProfileEntity>())) ?? [] { ctx.delete(p) }
        for w in (try? ctx.fetch(FetchDescriptor<WorkoutEntity>())) ?? [] { ctx.delete(w) }
        try? ctx.save()
    }
}

private struct DebugWorkoutHandle: WorkoutHandle {
    let id: UUID
    let title: String
}
