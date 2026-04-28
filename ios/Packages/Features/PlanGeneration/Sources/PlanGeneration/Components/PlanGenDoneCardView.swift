import SwiftUI
import DesignSystem

struct PlanGenDoneCardView: View {
    let title: String
    let onView: () -> Void

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                Text("Ready.")
                    .pulseFont(.h2)
                    .foregroundStyle(PulseColors.ink0.color)
                Text(title)
                    .pulseFont(.h1)
                    .foregroundStyle(PulseColors.ink0.color)
                PulseButton("View workout", variant: .primary, action: onView)
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
