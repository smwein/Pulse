import SwiftUI
import CoreModels
import DesignSystem

struct LevelStepView: View {
    @Binding var level: Profile.Level?

    private let options: [(value: Profile.Level, label: String, blurb: String)] = [
        (.new, "New", "Just starting out."),
        (.regular, "Regular", "Train a few times a week."),
        (.experienced, "Experienced", "Comfortable with most lifts."),
        (.athlete, "Athlete", "Train for performance."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.lg) {
            Text("Where are you now?")
                .pulseFont(.h1)
                .foregroundStyle(PulseColors.ink0.color)
            VStack(spacing: PulseSpacing.sm) {
                ForEach(options, id: \.value) { opt in
                    Button {
                        level = opt.value
                    } label: {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(opt.label).pulseFont(.h2)
                                Text(opt.blurb).pulseFont(.small)
                                    .foregroundStyle(PulseColors.ink2.color)
                            }
                            Spacer()
                            Image(systemName: level == opt.value ? "checkmark.circle.fill" : "circle")
                        }
                        .padding(PulseSpacing.md)
                        .frame(maxWidth: .infinity)
                        .background(level == opt.value ? PulseColors.bg2.color : PulseColors.bg1.color)
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
