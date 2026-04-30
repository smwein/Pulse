import SwiftUI
import CoreModels
import DesignSystem
import Repositories
import Onboarding
import PlanGeneration
import SwiftData
import HealthKitClient

public struct FirstRunGate<Content: View>: View {
    @State private var profile: Profile?
    @State private var isCheckingFirstRun = true
    @State private var pendingProfileForPlanGen: Profile?
    @State private var summaries: SevenDayHealthSummary?
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
        PlanRepository(modelContainer: appContainer.modelContainer, api: appContainer.api,
                       manifestURL: appContainer.manifestURL)
    }

    private var onboardingFlow: some View {
        OnboardingFlowView(
            profileRepo: profileRepo,
            themeStore: themeStore
        ) { newProfile in
            // Capture HK summaries before presenting plan-gen.
            let s = await appContainer.healthKit.sevenDaySummary()
            await MainActor.run {
                summaries = s
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
                streamProvider: { p in self.planRepo.streamFirstPlan(profile: p, coach: coach,
                                                                     summaries: self.summaries) },
                onPersistedWorkout: { _, ids in
                    if let id = ids.first {
                        let repo = WorkoutRepository(modelContainer: self.appContainer.modelContainer)
                        let title = (try? repo.latestWorkout())?.title ?? "Today's workout"
                        return PersistedWorkoutHandle(id: id, title: title)
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
        // Plan 4: clean up any orphan in-progress sessions from a prior crash.
        let sessionRepo = SessionRepository(modelContainer: appContainer.modelContainer)
        if let orphan = try? sessionRepo.orphanedInProgressSession() {
            try? sessionRepo.discardSession(id: orphan.id)
        }
        // Best-effort: refresh exercise asset manifest in the background.
        let assetRepo = ExerciseAssetRepository(
            modelContainer: appContainer.modelContainer,
            manifestURL: appContainer.manifestURL
        )
        if (try? assetRepo.allAssets())?.isEmpty == true {
            try? await assetRepo.refreshFromManifest()
        }
    }
}

private struct PersistedWorkoutHandle: WorkoutHandle {
    let id: UUID
    let title: String
}
