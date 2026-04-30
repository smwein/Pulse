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
import WatchBridge

public struct RootScaffold<DebugContent: View>: View {
    @State private var selectedTab: PulseTab = .today
    @State private var selectedWorkoutID: UUID?
    @State private var regeneratePresentedFor: Profile?
    @State private var regenerateSummaries: SevenDayHealthSummary?
    @State private var inWorkoutFor: UUID?
    @State private var completeForSessionID: UUID?
    @State private var watchMirror: PhoneWatchMirrorCoordinator?
    private let appContainer: AppContainer
    private let themeStore: ThemeStore
    private let watchTransport: (any WatchSessionTransport)?
    private let debugContent: () -> DebugContent

    public init(appContainer: AppContainer, themeStore: ThemeStore,
                watchTransport: (any WatchSessionTransport)? = nil,
                @ViewBuilder debugContent: @escaping () -> DebugContent) {
        self.appContainer = appContainer
        self.themeStore = themeStore
        self.watchTransport = watchTransport
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
        .task {
            guard watchMirror == nil, let watchTransport else { return }
            let mirror = PhoneWatchMirrorCoordinator(
                transport: watchTransport,
                modelContainer: appContainer.modelContainer,
                onWatchEndedSession: { sid in
                    inWorkoutFor = nil
                    completeForSessionID = sid
                }
            )
            mirror.start()
            watchMirror = mirror
        }
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
                onResumeWorkout: { id in inWorkoutFor = id },
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
                onResumeWorkout: { id in inWorkoutFor = id },
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
        TrainingProgressView(
            workoutRepo: WorkoutRepository(modelContainer: appContainer.modelContainer),
            profileRepo: ProfileRepository(modelContainer: appContainer.modelContainer)
        )
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
                onPersistedWorkout: { plan, ids in
                    if let id = ids.first {
                        let title = plan.workouts.first?.title ?? "Today's workout"
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
            watchTransport: watchTransport,
            workoutTitle: workout?.title ?? "Workout",
            activityKind: Self.activityKind(for: workout?.workoutType),
            onComplete: { sid in
                inWorkoutFor = nil
                completeForSessionID = sid
            },
            onDiscard: { inWorkoutFor = nil })
    }

    fileprivate static func activityKind(for workoutType: String?) -> String {
        switch workoutType?.lowercased() {
        case .some(let value) where value.contains("hiit"):
            return "highIntensityIntervalTraining"
        case .some(let value) where value.contains("run"):
            return "running"
        case .some(let value) where value.contains("cycle"):
            return "cycling"
        case .some(let value) where value.contains("mobility") || value.contains("yoga"):
            return "yoga"
        default:
            return "traditionalStrengthTraining"
        }
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
