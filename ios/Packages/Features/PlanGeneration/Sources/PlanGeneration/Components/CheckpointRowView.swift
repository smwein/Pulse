import SwiftUI
import DesignSystem

struct CheckpointRowView: View {
    let label: String

    var body: some View {
        HStack(spacing: PulseSpacing.sm) {
            Circle()
                .fill(PulseColors.ink2.color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(PulseColors.ink1.color)
            Spacer()
        }
    }
}
