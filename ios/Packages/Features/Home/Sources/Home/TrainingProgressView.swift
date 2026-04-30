import SwiftUI
import CoreModels
import DesignSystem
import Repositories

public struct TrainingProgressView: View {
    @State private var store: HomeStore

    public init(workoutRepo: WorkoutRepository, profileRepo: ProfileRepository) {
        _store = State(initialValue: HomeStore(workoutRepo: workoutRepo,
                                               profileRepo: profileRepo))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                if let stats = store.weeklyStats {
                    WeeklyProgressCardView(
                        stats: stats,
                        weeklyTargetMinutes: store.profile?.weeklyTargetMinutes ?? 0
                    )
                    progressDetails(stats)
                } else {
                    PulseCard {
                        Text("No training data yet")
                            .pulseFont(.body)
                            .foregroundStyle(PulseColors.ink1.color)
                    }
                }
            }
            .padding(PulseSpacing.lg)
        }
        .task { await store.refresh() }
    }

    private func progressDetails(_ stats: WeeklyProgressStats) -> some View {
        PulseCard {
            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                detailRow("Scheduled", "\(stats.scheduledWorkoutCount)")
                detailRow("Completed", "\(stats.completedSessionCount)")
                detailRow("Logged sets", "\(stats.loggedSetCount)")
                detailRow("Current streak", "\(stats.streakDays) days")
            }
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .pulseFont(.body)
                .foregroundStyle(PulseColors.ink1.color)
            Spacer()
            Text(value)
                .pulseFont(.body)
                .foregroundStyle(PulseColors.ink0.color)
        }
    }
}
