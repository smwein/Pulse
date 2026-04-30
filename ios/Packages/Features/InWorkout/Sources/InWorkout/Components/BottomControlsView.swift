import SwiftUI
import DesignSystem

struct BottomControlsView: View {
    let primaryLabel: String
    let onPrimary: () -> Void
    let onSkipRest: (() -> Void)?

    var body: some View {
        HStack {
            if let onSkipRest {
                PulseButton("Skip rest", variant: .ghost, action: onSkipRest)
            }
            Spacer()
            PulseButton(primaryLabel, variant: .primary, action: onPrimary)
        }
    }
}
