import SwiftUI
import DesignSystem

struct EquipmentStepView: View {
    @Binding var equipment: [String]

    private let options: [(key: String, label: String)] = [
        ("none", "Bodyweight only"),
        ("dumbbells", "Dumbbells"),
        ("barbell", "Barbell"),
        ("kettlebell", "Kettlebell"),
        ("bands", "Resistance bands"),
        ("full gym", "Full gym"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.lg) {
            Text("What do you have?")
                .pulseFont(.h1)
                .foregroundStyle(PulseColors.ink0.color)
            Text("Pick everything you can use.")
                .pulseFont(.small)
                .foregroundStyle(PulseColors.ink2.color)
            VStack(spacing: PulseSpacing.sm) {
                ForEach(options, id: \.key) { opt in
                    let selected = equipment.contains(opt.key)
                    Button {
                        if selected { equipment.removeAll { $0 == opt.key } }
                        else { equipment.append(opt.key) }
                    } label: {
                        HStack {
                            Text(opt.label).pulseFont(.body)
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
            Spacer()
        }
        .padding(PulseSpacing.lg)
    }
}
