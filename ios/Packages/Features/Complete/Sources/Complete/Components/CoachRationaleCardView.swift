import SwiftUI
import DesignSystem

struct CoachRationaleCardView: View {
    let coachName: String
    let rationale: String

    @Environment(\.pulseTheme) private var theme

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                Text(coachName)
                    .pulseFont(.small)
                    .foregroundStyle(theme.accent.base.color)
                Text(rationale)
                    .pulseFont(.body)
                    .foregroundStyle(PulseColors.ink0.color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
