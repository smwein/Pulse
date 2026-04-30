import SwiftUI
import DesignSystem

struct ExerciseCardView: View {
    let blockLabel: String
    let exerciseName: String
    let setIndexLabel: String   // "SET 2 OF 4"

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                Text(blockLabel.uppercased())
                    .pulseFont(.small)
                    .foregroundStyle(PulseColors.ink2.color)
                Text(exerciseName)
                    .pulseFont(.h1)
                    .foregroundStyle(PulseColors.ink0.color)
                Text(setIndexLabel)
                    .pulseFont(.small)
                    .foregroundStyle(PulseColors.ink2.color)
            }
        }
    }
}
