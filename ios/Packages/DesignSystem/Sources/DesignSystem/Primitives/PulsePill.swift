import SwiftUI

public struct PulsePill: View {
    public enum Variant { case `default`, accent }

    public let text: String
    public let variant: Variant

    @Environment(\.pulseTheme) private var theme

    public init(_ text: String, variant: Variant = .default) {
        self.text = text
        self.variant = variant
    }

    public var body: some View {
        Text(text)
            .pulseFont(.mono)
            .foregroundStyle(foreground)
            .padding(.horizontal, PulseSpacing.md)
            .padding(.vertical, PulseSpacing.xs + 2)
            .background(
                Capsule(style: .continuous).fill(background)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(PulseColors.line.color, lineWidth: variant == .accent ? 0 : 1)
            )
    }

    private var foreground: Color {
        switch variant {
        case .default: return PulseColors.ink1.color
        case .accent:  return theme.accent.base.color
        }
    }

    private var background: Color {
        switch variant {
        case .default: return PulseColors.bg2.color
        case .accent:  return theme.accent.soft.color
        }
    }
}
