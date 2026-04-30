import SwiftUI
import SwiftData
import CoreModels
import DesignSystem
import Persistence

struct RecapStepView: View {
    let session: SessionEntity?
    let workout: WorkoutEntity?
    let setLogs: [SetLogEntity]
    let coachName: String
    let onContinue: () -> Void

    @Environment(\.pulseTheme) private var theme

    var body: some View {
        ZStack {
            LinearGradient(colors: [
                PulseColors.bg0.color,
                theme.accent.base.color.opacity(0.15)
            ], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
            VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                Text("Workout complete")
                    .pulseFont(.h1)
                    .foregroundStyle(PulseColors.ink0.color)
                Text(workout?.title ?? "Today's session")
                    .pulseFont(.body)
                    .foregroundStyle(PulseColors.ink1.color)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: PulseSpacing.sm),
                                         count: 2),
                          spacing: PulseSpacing.sm) {
                    StatTileView(label: "TIME", value: timeString)
                    StatTileView(label: "AVG HR", value: "—")
                    StatTileView(label: "KCAL", value: "—")
                    StatTileView(label: "VOLUME", value: volumeString)
                }
                Spacer()
                PulseButton("Tell \(coachName) how it went", variant: .primary, action: onContinue)
            }
            .padding(PulseSpacing.lg)
        }
    }

    private var timeString: String {
        let s = session?.durationSec ?? 0
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private var volumeString: String {
        let total = setLogs.reduce(0) { acc, row in
            guard let kg = parseKg(row.load) else { return acc }
            return acc + (row.reps * kg)
        }
        return total > 0 ? "\(total) kg" : "—"
    }

    private func parseKg(_ s: String) -> Int? {
        let digits = s.prefix(while: { $0.isNumber })
        return Int(digits)
    }
}
