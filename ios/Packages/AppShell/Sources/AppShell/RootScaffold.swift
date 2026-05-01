import SwiftUI
import DesignSystem
import Repositories
import Home
import WorkoutDetail
import PlanGeneration
import InWorkout
import Complete
import CoreModels
import HealthKitClient

public struct RootScaffold<DebugContent: View>: View {
    @State private var selectedTab: PulseTab = .today
    @State private var selectedWorkoutID: UUID?
    @State private var regeneratePresentedFor: Profile?
    @State private var regenerateSummaries: SevenDayHealthSummary?
    @State private var inWorkoutFor: UUID?
    @State private var completeForSessionID: UUID?
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
                    ),
                    onStart: { wid in inWorkoutFor = wid }
                )
            }
        }
        .fullScreenCover(item: $regeneratePresentedFor) { profile in
            regenerateScreen(profile: profile)
        }
        .fullScreenCover(item: $inWorkoutFor) { wid in
            inWorkoutScreen(workoutID: wid)
        }
        .fullScreenCover(item: $completeForSessionID) { sid in
            completeScreen(sessionID: sid)
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
                    ),
                    onStart: { wid in inWorkoutFor = wid }
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
            Task {
                let s = await appContainer.healthKit.sevenDaySummary()
                await MainActor.run {
                    regenerateSummaries = s
                    regeneratePresentedFor = p
                }
            }
        }
    }

    @ViewBuilder
    private func regenerateScreen(profile: Profile) -> some View {
        if let coach = Coach.byID(profile.activeCoachID) {
            let planRepo = PlanRepository(modelContainer: appContainer.modelContainer, api: appContainer.api,
                                          manifestURL: appContainer.manifestURL)
            PlanGenerationView(
                profile: profile,
                coach: coach,
                mode: .regenerate,
                streamProvider: { p in planRepo.regenerate(profile: p, coach: coach,
                                                           summaries: regenerateSummaries) },
                onPersistedWorkout: { _, ids in
                    if let id = ids.first {
                        let repo = WorkoutRepository(modelContainer: appContainer.modelContainer)
                        let title = (try? repo.latestWorkout())?.title ?? "Today's workout"
                        return PersistedRegenHandle(id: id, title: title)
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

extension RootScaffold {
    @ViewBuilder
    fileprivate func inWorkoutScreen(workoutID: UUID) -> some View {
        let workoutRepo = WorkoutRepository(modelContainer: appContainer.modelContainer)
        let workout = (try? workoutRepo.workoutForID(workoutID)) ?? nil
        let flat: [SessionStore.FlatEntry] =
            workout.map { SessionStore.flatten(workout: $0) } ?? []
        let assetRepo = ExerciseAssetRepository(
            modelContainer: appContainer.modelContainer,
            manifestURL: appContainer.manifestURL)
        InWorkoutView(
            workoutID: workoutID,
            modelContainer: appContainer.modelContainer,
            flat: flat,
            assetRepo: assetRepo,
            transport: appContainer.transport,
            mirroredObserver: appContainer.mirroredObserver,
            healthKit: appContainer.healthKit,
            onComplete: { sid in
                inWorkoutFor = nil
                completeForSessionID = sid
            },
            onDiscard: { inWorkoutFor = nil })
    }

    @ViewBuilder
    fileprivate func completeScreen(sessionID: UUID) -> some View {
        let profileRepo = ProfileRepository(modelContainer: appContainer.modelContainer)
        if let profile = profileRepo.currentProfile(),
           let coach = Coach.byID(profile.activeCoachID) {
            CompleteView(sessionID: sessionID,
                         modelContainer: appContainer.modelContainer,
                         api: appContainer.api,
                         healthKit: appContainer.healthKit,
                         manifestURL: appContainer.manifestURL,
                         coach: coach,
                         profile: profile,
                         onDismiss: {
                             completeForSessionID = nil
                             selectedWorkoutID = nil
                         })
        }
    }
}
