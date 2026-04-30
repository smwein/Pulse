import SwiftUI
import DesignSystem

struct FeedbackTagPill: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .pulseFont(.small)
                .foregroundStyle(isSelected ? PulseColors.bg0.color : PulseColors.ink0.color)
                .padding(.horizontal, PulseSpacing.md)
                .padding(.vertical, PulseSpacing.xs)
                .background(isSelected ? PulseColors.ink0.color : PulseColors.bg2.color)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
