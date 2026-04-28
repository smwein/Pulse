import SwiftUI
import DesignSystem

struct StreamingTextPaneView: View {
    let text: String

    var body: some View {
        ScrollView {
            Text(text)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(PulseColors.ink2.color)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .animation(.easeOut(duration: 0.15), value: text)
        }
        .frame(maxHeight: 160)
        .padding(PulseSpacing.md)
        .background(PulseColors.bg1.color)
        .clipShape(RoundedRectangle(cornerRadius: PulseRadius.md))
    }
}
