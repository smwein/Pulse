import SwiftUI
import CoreModels
import DesignSystem

struct AdjustmentCardView: View {
    let adjustment: Adjustment

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(adjustment.label)
                    .pulseFont(.h2)
                    .foregroundStyle(PulseColors.ink0.color)
                Text(adjustment.detail)
                    .pulseFont(.small)
                    .foregroundStyle(PulseColors.ink2.color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
