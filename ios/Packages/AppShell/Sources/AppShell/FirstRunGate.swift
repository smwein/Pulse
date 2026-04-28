import SwiftUI
import CoreModels
import DesignSystem
import Repositories
import Onboarding
import PlanGeneration

public struct FirstRunGate<Content: View>: View {
    @State private var profile: Profile?
    @State private var isCheckingFirstRun = true
    @State private var pendingProfileForPlanGen: Profile?
    private let appContainer: AppContainer
    private let themeStore: ThemeStore
    private let content: () -> Content

    public init(appContainer: AppContainer,
                themeStore: ThemeStore,
                @ViewBuilder content: @escaping () -> Content) {
        self.appContainer = appContainer
        self.themeStore = themeStore
        self.content = content
    }

    public var body: some View {
        Group {
            if isCheckingFirstRun {
                Color.clear
            } else if profile == nil {
                onboardingFlow
            } else {
                #if os(iOS)
                content()
                    .fullScreenCover(item: $pendingProfileForPlanGen) { prof in
                        planGenScreen(profile: prof)
                    }
                #else
                content()
                #endif
            }
        }
        .task { await checkFirstRun() }
    }

    private var profileRepo: ProfileRepository {
        ProfileRepository(modelContainer: appContainer.modelContainer)
    }

    private var planRepo: PlanRepository {
        PlanRepository(modelContainer: appContainer.modelContainer, api: appContainer.api)
    }

    private var onboardingFlow: some View {
        OnboardingFlowView(
            profileRepo: profileRepo,
            themeStore: themeStore
        ) { newProfile in
            await MainActor.run {
                profile = newProfile
                pendingProfileForPlanGen = newProfile
            }
        }
    }

    @ViewBuilder
    private func planGenScreen(profile: Profile) -> some View {
        if let coach = Coach.byID(profile.activeCoachID) {
            PlanGenerationView(
                profile: profile,
                coach: coach,
                mode: .firstPlan,
                streamProvider: { p in self.planRepo.streamFirstPlan(profile: p, coach: coach) },
                onPersistedWorkout: { _ in
                    let repo = WorkoutRepository(modelContainer: self.appContainer.modelContainer)
                    if let w = try? repo.latestWorkout() {
                        return PersistedWorkoutHandle(id: w.id, title: w.title)
                    }
                    return nil
                },
                onViewWorkout: { _ in pendingProfileForPlanGen = nil },
                onBackToHome: { pendingProfileForPlanGen = nil }
            )
        }
    }

    private func checkFirstRun() async {
        let p = profileRepo.currentProfile()
        await MainActor.run {
            self.profile = p
            if let p, let coach = Coach.byID(p.activeCoachID) {
                self.themeStore.setActiveCoach(id: coach.id)
            }
            self.isCheckingFirstRun = false
        }
    }
}

private struct PersistedWorkoutHandle: WorkoutHandle {
    let id: UUID
    let title: String
}
