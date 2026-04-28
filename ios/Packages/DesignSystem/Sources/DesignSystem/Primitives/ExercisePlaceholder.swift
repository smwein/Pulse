import SwiftUI

/// Stand-in for the cinematic exercise demo loop. Real video lands when AVPlayer
/// integration ships in Plan 3 (PlanGeneration → Workout Detail).
public struct ExercisePlaceholder: View {
    public let label: String

    @Environment(\.pulseTheme) private var theme

    public init(label: String) {
        self.label = label
    }

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    theme.accent.base.color.opacity(0.35),
                    PulseColors.bg2.color,
                    PulseColors.bg0.color,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [theme.accent.base.color.opacity(0.18), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 280
            )
            VStack {
                Spacer()
                HStack {
                    Text(label.uppercased())
                        .pulseFont(.eyebrow)
                        .foregroundStyle(PulseColors.ink2.color)
                    Spacer()
                }
            }
            .padding(PulseSpacing.lg)
        }
        .clipShape(RoundedRectangle(cornerRadius: PulseRadius.lg, style: .continuous))
    }
}
