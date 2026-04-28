import SwiftUI
import CoreModels
import DesignSystem

struct CoachPickStepView: View {
    @Binding var activeCoachID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.lg) {
            Text("Who's coaching you?")
                .pulseFont(.h1)
                .foregroundStyle(PulseColors.ink0.color)

            VStack(spacing: PulseSpacing.md) {
                ForEach(Coach.all) { coach in
                    coachCard(coach)
                }
            }

            if let id = activeCoachID, let coach = Coach.byID(id) {
                PulseCard {
                    Text(CoachStrings.onboardingWelcome(for: coach.id))
                        .pulseFont(.body)
                        .foregroundStyle(PulseColors.ink0.color)
                }
            }
            Spacer()
        }
        .padding(PulseSpacing.lg)
    }

    @ViewBuilder
    private func coachCard(_ coach: Coach) -> some View {
        let selected = activeCoachID == coach.id
        Button { activeCoachID = coach.id } label: {
            HStack(spacing: PulseSpacing.md) {
                CoachAvatar(coach: coach, size: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text(coach.displayName).pulseFont(.h2)
                        .foregroundStyle(PulseColors.ink0.color)
                    Text(coach.tagline).pulseFont(.small)
                        .foregroundStyle(PulseColors.ink2.color)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(PulseColors.ink0.color)
            }
            .padding(PulseSpacing.md)
            .background(selected ? PulseColors.bg2.color : PulseColors.bg1.color)
            .clipShape(RoundedRectangle(cornerRadius: PulseRadius.md))
        }
        .buttonStyle(.plain)
    }
}
