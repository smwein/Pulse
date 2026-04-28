import SwiftUI
import DesignSystem

struct NameStepView: View {
    @Binding var displayName: String

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.lg) {
            Text("What should I call you?")
                .pulseFont(.h1)
                .foregroundStyle(PulseColors.ink0.color)
            TextField("Your name", text: $displayName)
                .pulseFont(.body)
                .foregroundStyle(PulseColors.ink0.color)
                .padding(PulseSpacing.md)
                .background(PulseColors.bg2.color)
                .clipShape(RoundedRectangle(cornerRadius: PulseRadius.md))
                .autocorrectionDisabled()
#if canImport(UIKit)
                .textInputAutocapitalization(.words)
#endif
            Spacer()
        }
        .padding(PulseSpacing.lg)
    }
}
