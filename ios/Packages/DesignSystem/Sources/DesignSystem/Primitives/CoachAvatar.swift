import SwiftUI
import CoreModels

public struct CoachAvatar: View {
    public let coach: Coach
    public let size: CGFloat

    public init(coach: Coach, size: CGFloat = 56) {
        self.coach = coach
        self.size = size
    }

    private var palette: AccentPalette { AccentPalette(hue: coach.accentHue) }

    private var initial: String {
        coach.displayName.prefix(1).uppercased()
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [palette.base.color, palette.ink.color],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            Text(initial)
                .pulseFont(PulseFont(family: .display, size: size * 0.5,
                                     weight: .regular, italic: true))
                .foregroundStyle(palette.ink.color)
        }
        .frame(width: size, height: size)
        .overlay(
            Circle().strokeBorder(PulseColors.lineSoft.color, lineWidth: 1)
        )
    }
}
