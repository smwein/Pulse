import SwiftUI

public struct Ring: View {
    public let progress: Double
    public let size: CGFloat
    public let lineWidth: CGFloat

    @Environment(\.pulseTheme) private var theme

    public init(progress: Double, size: CGFloat = 120, lineWidth: CGFloat = 10) {
        self.progress = progress
        self.size = size
        self.lineWidth = lineWidth
    }

    public var clampedProgress: Double {
        max(0, min(1, progress))
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(PulseColors.bg2.color, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(theme.accent.base.color,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(PulseMotion.easeOut, value: clampedProgress)
        }
        .frame(width: size, height: size)
    }
}
