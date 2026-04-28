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

struct DebugFeatureSmokeView: View {
    let appContainer: AppContainer
    let themeStore: ThemeStore

    @State private var route: Route?

    private enum Route: Identifiable, Hashable {
        case onboarding
        case planGen
        case home
        case workoutDetail(UUID)
        var id: String {
            switch self {
            case .onboarding: return "onboarding"
            case .planGen: return "planGen"
            case .home: return "home"
            case .workoutDetail(let id): return "wd-\(id)"
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
                    manifestURL: URL(string: "https://placeholder.invalid/manifest.json")!
                )
            )
        }
    }

    @ViewBuilder
    private func planGenView() -> some View {
        let profileRepo = ProfileRepository(modelContainer: appContainer.modelContainer)
        if let profile = profileRepo.currentProfile(),
           let coach = Coach.byID(profile.activeCoachID) {
            let planRepo = PlanRepository(modelContainer: appContainer.modelContainer, api: appContainer.api)
            PlanGenerationView(
                profile: profile, coach: coach, mode: .firstPlan,
                streamProvider: { p in planRepo.streamFirstPlan(profile: p, coach: coach) },
                onPersistedWorkout: { _ in
                    let repo = WorkoutRepository(modelContainer: appContainer.modelContainer)
                    if let w = try? repo.latestWorkout() {
                        return DebugWorkoutHandle(id: w.id, title: w.title)
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
