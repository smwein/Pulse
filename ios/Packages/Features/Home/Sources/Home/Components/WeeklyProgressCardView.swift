import SwiftUI
import DesignSystem
import Repositories

public struct WeeklyProgressCardView: View {
    let stats: WeeklyProgressStats
    let weeklyTargetMinutes: Int

    public init(stats: WeeklyProgressStats, weeklyTargetMinutes: Int) {
        self.stats = stats
        self.weeklyTargetMinutes = weeklyTargetMinutes
    }

    public var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                        Text("WEEK")
                            .pulseFont(.small)
                            .foregroundStyle(PulseColors.ink2.color)
                        Text("\(stats.completedMinutes) / \(weeklyTargetMinutes) min")
                            .pulseFont(.h2)
                            .foregroundStyle(PulseColors.ink0.color)
                    }
                    Spacer()
                    Ring(progress: progress)
                        .frame(width: 56, height: 56)
                }
                HStack(spacing: PulseSpacing.sm) {
                    statTile(value: "\(stats.completedSessionCount)", label: "sessions")
                    statTile(value: "\(stats.streakDays)", label: "streak")
                    statTile(value: "\(stats.loggedSetCount)", label: "sets")
                }
            }
        }
    }

    private var progress: Double {
        guard weeklyTargetMinutes > 0 else { return 0 }
        return min(1, Double(stats.completedMinutes) / Double(weeklyTargetMinutes))
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .pulseFont(.h3)
                .foregroundStyle(PulseColors.ink0.color)
            Text(label)
                .pulseFont(.small)
                .foregroundStyle(PulseColors.ink2.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PulseSpacing.sm)
        .background(PulseColors.bg2.color)
        .clipShape(RoundedRectangle(cornerRadius: PulseRadius.sm, style: .continuous))
    }
}
