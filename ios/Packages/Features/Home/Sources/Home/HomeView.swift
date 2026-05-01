import SwiftUI
import CoreModels
import DesignSystem
import Persistence
import Repositories

public struct HomeView: View {
    @State private var store: HomeStore
    private let onViewWorkout: (UUID) -> Void
    private let onRegenerate: () -> Void

    public init(workoutRepo: WorkoutRepository,
                profileRepo: ProfileRepository,
                onViewWorkout: @escaping (UUID) -> Void,
                onRegenerate: @escaping () -> Void) {
        _store = State(initialValue: HomeStore(workoutRepo: workoutRepo,
                                               profileRepo: profileRepo))
        self.onViewWorkout = onViewWorkout
        self.onRegenerate = onRegenerate
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                if store.watchHKDeniedBannerVisible {
                    watchHKDeniedBanner
                }
                if let profile = store.profile {
                    Text(greetingText(for: profile))
                        .pulseFont(.h2)
                        .foregroundStyle(PulseColors.ink0.color)
                }
                if let w = store.todaysWorkout {
                    WorkoutHeroCardView(
                        title: w.title,
                        subtitle: w.subtitle,
                        durationMin: w.durationMin,
                        workoutType: w.workoutType
                    ) { onViewWorkout(w.id) }
                } else {
                    PulseCard {
                        VStack(alignment: .leading, spacing: PulseSpacing.md) {
                            Text("No plan yet")
                                .pulseFont(.h2)
                                .foregroundStyle(PulseColors.ink0.color)
                            PulseButton("Generate today's workout",
                                        variant: .primary, action: onRegenerate)
                        }
                    }
                }
                weekStrip
                if store.todaysWorkout != nil {
                    PulseButton("Regenerate today's plan",
                                variant: .ghost, action: onRegenerate)
                }
            }
            .padding(PulseSpacing.lg)
        }
        .task { await store.refresh() }
    }

    private func greetingText(for profile: Profile) -> String {
        let prefix = CoachStrings.homeGreeting(for: profile.activeCoachID)
        return "\(prefix), \(profile.displayName)."
    }

    private var weekStrip: some View {
        let calendar = Calendar(identifier: .iso8601)
        var filled: Set<DateComponents> = []
        if let date = store.todaysWorkout?.scheduledFor {
            filled.insert(calendar.dateComponents([.year, .month, .day], from: date))
        }
        return WeekStripView(filledDates: filled, calendar: calendar)
    }

    private var watchHKDeniedBanner: some View {
        PulseCard {
            HStack(alignment: .top, spacing: PulseSpacing.sm) {
                VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                    Text("Watch declined HealthKit access")
                        .pulseFont(.h3)
                        .foregroundStyle(PulseColors.ink0.color)
                    Text("Open the Watch app and grant write access to log workouts to Health.")
                        .pulseFont(.small)
                        .foregroundStyle(PulseColors.ink1.color)
                }
                Spacer()
                IconButton(systemName: "xmark") {
                    store.dismissWatchHKBanner()
                }
            }
        }
    }
}
