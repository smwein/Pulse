import SwiftUI

public struct PulseButton: View {
    public enum Variant { case primary, ghost }
    public enum Size { case regular, large }

    public let title: String
    public let variant: Variant
    public let size: Size
    public let action: () -> Void

    @Environment(\.pulseTheme) private var theme

    public init(_ title: String, variant: Variant = .primary, size: Size = .regular,
                action: @escaping () -> Void) {
        self.title = title
        self.variant = variant
        self.size = size
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .pulseFont(size == .large ? PulseFont.h3 : PulseFont.body)
                .padding(.horizontal, size == .large ? 26 : 18)
                .padding(.vertical, size == .large ? 18 : 12)
                .frame(minWidth: 0)
                .foregroundStyle(foreground)
                .background(background)
                .overlay(border)
                .clipShape(RoundedRectangle(cornerRadius: PulseRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var foreground: Color {
        switch variant {
        case .primary: return theme.accent.ink.color
        case .ghost:   return PulseColors.ink0.color
        }
    }

    private var background: some View {
        Group {
            switch variant {
            case .primary: theme.accent.base.color
            case .ghost:   PulseColors.bg1.color
            }
        }
    }

    @ViewBuilder
    private var border: some View {
        if variant == .ghost {
            RoundedRectangle(cornerRadius: PulseRadius.md, style: .continuous)
                .strokeBorder(PulseColors.line.color, lineWidth: 1)
        }
    }
}
