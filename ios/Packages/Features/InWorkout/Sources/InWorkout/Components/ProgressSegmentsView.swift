import SwiftUI
import DesignSystem

struct ProgressSegmentsView: View {
    let total: Int
    let completed: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<max(total, 1), id: \.self) { i in
                Capsule()
                    .fill(i < completed ? PulseColors.ink0.color : PulseColors.bg2.color)
                    .frame(height: 4)
            }
        }
    }
}
