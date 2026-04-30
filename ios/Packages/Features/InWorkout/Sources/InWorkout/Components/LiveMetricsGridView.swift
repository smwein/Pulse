import SwiftUI
import DesignSystem

struct LiveMetricsGridView: View {
    let elapsed: String  // "12:34"
    let restRemaining: String  // "0:45" or "—"
    let avgHR: String  // "—" until Plan 5

    var body: some View {
        HStack(spacing: PulseSpacing.sm) {
            tile(label: "TIME", value: elapsed)
            tile(label: "REST", value: restRemaining)
            tile(label: "HR", value: avgHR)
        }
    }

    private func tile(label: String, value: String) -> some View {
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
