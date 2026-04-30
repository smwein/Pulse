import SwiftUI
import DesignSystem

public struct WorkoutHeroCardView: View {
    let title: String
    let subtitle: String
    let durationMin: Int
    let workoutType: String
    let status: String
    let actionLabel: String
    let onView: () -> Void

    public init(title: String, subtitle: String, durationMin: Int,
                workoutType: String, status: String = "scheduled",
                actionLabel: String = "View workout",
                onView: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.durationMin = durationMin
        self.workoutType = workoutType
        self.status = status
        self.actionLabel = actionLabel
        self.onView = onView
    }

    public var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                HStack {
                    Text(workoutType.uppercased())
                        .pulseFont(.small)
                        .foregroundStyle(PulseColors.ink2.color)
                    Spacer()
                    PulsePill(statusLabel, variant: status == "completed" ? .accent : .default)
                }
                Text(title)
                    .pulseFont(.h1)
                    .foregroundStyle(PulseColors.ink0.color)
                Text(subtitle)
                    .pulseFont(.body)
                    .foregroundStyle(PulseColors.ink1.color)
                HStack(spacing: PulseSpacing.sm) {
                    PulsePill("\(durationMin) min", variant: .default)
                    PulsePill(workoutType, variant: .accent)
                }
                PulseButton(actionLabel, variant: status == "completed" ? .ghost : .primary, action: onView)
            }
        }
    }

    private var statusLabel: String {
        switch status {
        case "in_progress": return "LIVE"
        case "completed": return "DONE"
        default: return "TODAY"
        }
    }
}
