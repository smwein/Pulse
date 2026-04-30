import SwiftUI
import CoreModels
import DesignSystem

struct NextSessionPreviewCardView: View {
    let title: String
    let subtitle: String
    let workoutType: String
    let durationMin: Int
    let scheduledFor: Date

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                Text(weekdayString)
                    .pulseFont(.small)
                    .foregroundStyle(PulseColors.ink2.color)
                Text(title)
                    .pulseFont(.h2)
                    .foregroundStyle(PulseColors.ink0.color)
                Text(subtitle)
                    .pulseFont(.small)
                    .foregroundStyle(PulseColors.ink1.color)
                HStack(spacing: PulseSpacing.sm) {
                    PulsePill("\(durationMin) min", variant: .default)
                    PulsePill(workoutType, variant: .accent)
                }
            }
        }
    }

    private var weekdayString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: scheduledFor).uppercased()
    }
}
