import SwiftUI
import CoreModels
import DesignSystem
import Persistence
import Repositories

public struct HomeView: View {
    @State private var store: HomeStore
    private let onViewWorkout: (UUID) -> Void
    private let onResumeWorkout: (UUID) -> Void
    private let onRegenerate: () -> Void

    public init(workoutRepo: WorkoutRepository,
                profileRepo: ProfileRepository,
                onViewWorkout: @escaping (UUID) -> Void,
                onResumeWorkout: @escaping (UUID) -> Void = { _ in },
                onRegenerate: @escaping () -> Void) {
        _store = State(initialValue: HomeStore(workoutRepo: workoutRepo,
                                               profileRepo: profileRepo))
        self.onViewWorkout = onViewWorkout
        self.onResumeWorkout = onResumeWorkout
        self.onRegenerate = onRegenerate
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PulseSpacing.lg) {
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
                        workoutType: w.workoutType,
                        status: w.status,
                        actionLabel: store.workoutActionLabel
                    ) {
                        if w.status == "in_progress" {
                            onResumeWorkout(w.id)
                        } else {
                            onViewWorkout(w.id)
                        }
                    }
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
                if let stats = store.weeklyStats,
                   let target = store.profile?.weeklyTargetMinutes {
                    WeeklyProgressCardView(stats: stats, weeklyTargetMinutes: target)
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
        for date in store.weeklyStats?.completedDates ?? [] {
            filled.insert(calendar.dateComponents([.year, .month, .day], from: date))
        }
        return WeekStripView(filledDates: filled, calendar: calendar)
    }
}
