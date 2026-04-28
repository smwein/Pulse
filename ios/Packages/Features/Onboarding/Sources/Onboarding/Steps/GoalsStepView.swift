import SwiftUI
import DesignSystem

struct GoalsStepView: View {
    @Binding var goals: [String]

    private let options: [(key: String, label: String)] = [
        ("build muscle", "Build muscle"),
        ("lose fat", "Lose fat"),
        ("get stronger", "Get stronger"),
        ("conditioning", "Conditioning"),
        ("mobility", "Mobility"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.lg) {
            Text("What are you here for?")
                .pulseFont(.h1)
                .foregroundStyle(PulseColors.ink0.color)
            Text("Pick one or more.")
                .pulseFont(.small)
                .foregroundStyle(PulseColors.ink2.color)
            VStack(spacing: PulseSpacing.sm) {
                ForEach(options, id: \.key) { opt in
                    toggleRow(key: opt.key, label: opt.label)
                }
            }
            Spacer()
        }
        .padding(PulseSpacing.lg)
    }

    @ViewBuilder
    private func toggleRow(key: String, label: String) -> some View {
        let selected = goals.contains(key)
        Button {
            if selected {
                goals.removeAll { $0 == key }
            } else {
                goals.append(key)
            }
        } label: {
            HStack {
                Text(label).pulseFont(.body)
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
            }
            .padding(PulseSpacing.md)
            .frame(maxWidth: .infinity)
            .background(selected ? PulseColors.bg2.color : PulseColors.bg1.color)
            .clipShape(RoundedRectangle(cornerRadius: PulseRadius.md))
            .foregroundStyle(PulseColors.ink0.color)
        }
        .buttonStyle(.plain)
    }
}
