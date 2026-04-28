import SwiftUI

public struct PulseCard<Content: View>: View {
    private let content: Content
    private let padding: CGFloat
    private let cornerRadius: CGFloat

    public init(padding: CGFloat = PulseSpacing.lg,
                cornerRadius: CGFloat = PulseRadius.lg,
                @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(PulseColors.bg1.color)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(PulseColors.line.color, lineWidth: 1)
            )
    }
}
