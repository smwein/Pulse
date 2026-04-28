import SwiftUI
import DesignSystem

struct FrequencyStepView: View {
    @Binding var frequencyPerWeek: Int?
    @Binding var weeklyTargetMinutes: Int?

    private let frequencies = [3, 4, 5, 6]
    private let durations = [30, 45, 60, 90]

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.lg) {
            Text("How much can you commit?")
                .pulseFont(.h1)
                .foregroundStyle(PulseColors.ink0.color)

            sectionTitle("Days per week")
            chipRow(values: frequencies, selected: frequencyPerWeek) { frequencyPerWeek = $0 }

            sectionTitle("Minutes per session")
            chipRow(values: durations, selected: weeklyTargetMinutes) { weeklyTargetMinutes = $0 }

            Spacer()
        }
        .padding(PulseSpacing.lg)
    }

    private func sectionTitle(_ s: String) -> some View {
        Text(s)
            .pulseFont(.small)
            .foregroundStyle(PulseColors.ink2.color)
    }

    private func chipRow(values: [Int], selected: Int?, set: @escaping (Int) -> Void) -> some View {
        HStack(spacing: PulseSpacing.sm) {
            ForEach(values, id: \.self) { v in
                Button { set(v) } label: {
                    Text("\(v)")
                        .pulseFont(.body)
                        .padding(.horizontal, PulseSpacing.md)
                        .padding(.vertical, PulseSpacing.sm)
                        .background(selected == v ? PulseColors.bg2.color : PulseColors.bg1.color)
                        .clipShape(Capsule())
                        .foregroundStyle(PulseColors.ink0.color)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
