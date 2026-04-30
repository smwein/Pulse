import SwiftUI
import DesignSystem

struct StatTileView: View {
    let label: String
    let value: String

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .pulseFont(.small)
                    .foregroundStyle(PulseColors.ink2.color)
                Text(value)
                    .pulseFont(.h2)
                    .foregroundStyle(PulseColors.ink0.color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
