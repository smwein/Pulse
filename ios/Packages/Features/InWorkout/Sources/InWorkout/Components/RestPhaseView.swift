import SwiftUI
import DesignSystem

struct RestPhaseView: View {
    let restRemaining: Int
    let nextLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.lg) {
            Text("REST")
                .pulseFont(.small)
                .foregroundStyle(PulseColors.ink2.color)
            Text(formatted(restRemaining))
                .pulseFont(.h1)
                .foregroundStyle(PulseColors.ink0.color)
            Text("Up next: \(nextLabel)")
                .pulseFont(.body)
                .foregroundStyle(PulseColors.ink1.color)
        }
        .padding(PulseSpacing.lg)
    }

    private func formatted(_ s: Int) -> String {
        String(format: "%d:%02d", s / 60, s % 60)
    }
}
