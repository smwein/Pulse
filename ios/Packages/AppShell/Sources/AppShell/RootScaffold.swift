import SwiftUI
import DesignSystem
import Repositories
import Home
import WorkoutDetail
import PlanGeneration
import CoreModels

public struct RootScaffold<DebugContent: View>: View {
    @State private var selectedTab: PulseTab = .today
    @State private var selectedWorkoutID: UUID?
    @State private var regeneratePresentedFor: Profile?
    private let appContainer: AppContainer
    private let themeStore: ThemeStore
    private let debugContent: () -> DebugContent

    public init(appContainer: AppContainer, themeStore: ThemeStore,
                @ViewBuilder debugContent: @escaping () -> DebugContent) {
        self.appContainer = appContainer
        self.themeStore = themeStore
        self.debugContent = debugContent
    }

    public var body: some View {
        ZStack {
            PulseColors.bg0.color.ignoresSafeArea()
            VStack(spacing: 0) {
                TopBar(eyebrow: "PULSE", title: tabTitle) {
                    IconButton(systemName: "wrench.and.screwdriver") {
                        selectedTab = .debug
                    }
                }
                Group {
                    switch selectedTab {
                    case .today: todayTab
                    case .progress: progressPlaceholder
                    case .debug: debugContent()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                PulseTabBar(selected: $selectedTab)
            }
        }
        .pulseTheme(themeStore)
        .preferredColorScheme(.dark)
    }

    private var tabTitle: String {
        switch selectedTab {
        case .today:    return "Today"
        case .progress: return "Progress"
        case .debug:    return "Debug"
        }
    }

    @ViewBuilder
    private var todayTab: some View {
        #if os(iOS)
        NavigationStack {
            HomeView(
                workoutRepo: WorkoutRepository(modelContainer: appContainer.modelContainer),
                profileRepo: ProfileRepository(modelContainer: appContainer.modelContainer),
                onViewWorkout: { id in selectedWorkoutID = id },
                onRegenerate: { triggerRegenerate() }
            )
            .navigationDestination(item: $selectedWorkoutID) { id in
                WorkoutDetailView(
                    workoutID: id,
                    modelContainer: appContainer.modelContainer,
                    assetRepo: ExerciseAssetRepository(
                        modelContainer: appContainer.modelContainer,
                        manifestURL: appContainer.manifestURL
                    )
                )
            }
        }
        .fullScreenCover(item: $regeneratePresentedFor) { profile in
            regenerateScreen(profile: profile)
        }
        #else
        NavigationStack {
            HomeView(
                workoutRepo: WorkoutRepository(modelContainer: appContainer.modelContainer),
                profileRepo: ProfileRepository(modelContainer: appContainer.modelContainer),
                onViewWorkout: { id in selectedWorkoutID = id },
                onRegenerate: { triggerRegenerate() }
            )
            .navigationDestination(item: $selectedWorkoutID) { id in
                WorkoutDetailView(
                    workoutID: id,
                    modelContainer: appContainer.modelContainer,
                    assetRepo: ExerciseAssetRepository(
                        modelContainer: appContainer.modelContainer,
                        manifestURL: appContainer.manifestURL
                    )
                )
            }
        }
        #endif
    }

    private var progressPlaceholder: some View {
        VStack(spacing: PulseSpacing.lg) {
            Ring(progress: 0.42)
            Text("Weekly ring (placeholder)")
                .pulseFont(.small)
                .foregroundStyle(PulseColors.ink2.color)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func triggerRegenerate() {
        let repo = ProfileRepository(modelContainer: appContainer.modelContainer)
        if let p = repo.currentProfile() {
            regeneratePresentedFor = p
        }
    }

    @ViewBuilder
    private func regenerateScreen(profile: Profile) -> some View {
        if let coach = Coach.byID(profile.activeCoachID) {
            let planRepo = PlanRepository(modelContainer: appContainer.modelContainer, api: appContainer.api)
            PlanGenerationView(
                profile: profile,
                coach: coach,
                mode: .regenerate,
                streamProvider: { p in planRepo.regenerate(profile: p, coach: coach) },
                onPersistedWorkout: { _ in
                    let repo = WorkoutRepository(modelContainer: appContainer.modelContainer)
                    if let w = try? repo.latestWorkout() {
                        return PersistedRegenHandle(id: w.id, title: w.title)
                    }
                    return nil
                },
                onViewWorkout: { id in
                    regeneratePresentedFor = nil
                    selectedWorkoutID = id
                },
                onBackToHome: { regeneratePresentedFor = nil }
            )
        }
    }
}

private struct PersistedRegenHandle: WorkoutHandle {
    let id: UUID
    let title: String
}
