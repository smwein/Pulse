import SwiftUI
import DesignSystem

public struct WorkoutHeroCardView: View {
    let title: String
    let subtitle: String
    let durationMin: Int
    let workoutType: String
    let onView: () -> Void

    public init(title: String, subtitle: String, durationMin: Int,
                workoutType: String, onView: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.durationMin = durationMin
        self.workoutType = workoutType
        self.onView = onView
    }

    public var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                Text(workoutType.uppercased())
                    .pulseFont(.small)
                    .foregroundStyle(PulseColors.ink2.color)
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
                PulseButton("View workout", variant: .primary, action: onView)
            }
        }
    }
}
