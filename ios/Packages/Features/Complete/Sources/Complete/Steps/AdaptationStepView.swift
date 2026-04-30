import SwiftUI
import CoreModels
import DesignSystem

struct AdaptationStepView: View {
    @Bindable var store: CompleteStore
    let coachName: String
    let onDone: () -> Void

    var body: some View {
        ZStack {
            PulseColors.bg0.color.ignoresSafeArea()
            switch store.adaptation {
            case .idle, .streaming:
                thinking
            case .done(let payload):
                result(payload)
            case .failed(let err):
                failed(err)
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var thinking: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.lg) {
            Text("\(coachName) is adapting tomorrow…")
                .pulseFont(.h1)
                .foregroundStyle(PulseColors.ink0.color)
            if case .streaming(let cps, let adjs, let rat, let wo) = store.adaptation {
                ForEach(Array(cps.enumerated()), id: \.offset) { _, cp in
                    Text("⟦\(cp)⟧")
                        .pulseFont(.small)
                        .foregroundStyle(PulseColors.ink2.color)
                        .monospaced()
                }
                if !adjs.isEmpty {
                    VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                        ForEach(adjs) { AdjustmentCardView(adjustment: $0) }
                    }
                }
                if let rat {
                    CoachRationaleCardView(coachName: coachName, rationale: rat)
                }
                if let wo {
                    NextSessionPreviewCardView(title: wo.title, subtitle: wo.subtitle,
                        workoutType: wo.workoutType, durationMin: wo.durationMin,
                        scheduledFor: wo.scheduledFor)
                }
            }
            Spacer()
        }
        .padding(PulseSpacing.lg)
    }

    @ViewBuilder
    private func result(_ payload: AdaptationPayload) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                Text("\(coachName) adapted tomorrow")
                    .pulseFont(.h1)
                    .foregroundStyle(PulseColors.ink0.color)
                if !payload.adjustments.isEmpty {
                    Text("CHANGES")
                        .pulseFont(.small)
                        .foregroundStyle(PulseColors.ink2.color)
                    VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                        ForEach(payload.adjustments) { AdjustmentCardView(adjustment: $0) }
                    }
                }
                if !payload.rationale.isEmpty {
                    CoachRationaleCardView(coachName: coachName, rationale: payload.rationale)
                }
                NextSessionPreviewCardView(
                    title: payload.newWorkout.title,
                    subtitle: payload.newWorkout.subtitle,
                    workoutType: payload.newWorkout.workoutType,
                    durationMin: payload.newWorkout.durationMin,
                    scheduledFor: payload.newWorkout.scheduledFor)
                Spacer()
                PulseButton("Done — see you \(weekday(payload.newWorkout.scheduledFor))",
                            variant: .primary, action: onDone)
            }
            .padding(PulseSpacing.lg)
        }
    }

    @ViewBuilder
    private func failed(_ error: Error) -> some View {
        VStack(alignment: .leading, spacing: PulseSpacing.lg) {
            Text("Couldn't get an adaptation")
                .pulseFont(.h1)
                .foregroundStyle(PulseColors.ink0.color)
            Text("Your feedback is saved. We'll try again next session.")
                .pulseFont(.body)
                .foregroundStyle(PulseColors.ink2.color)
            Spacer()
            PulseButton("Done", variant: .primary, action: onDone)
        }
        .padding(PulseSpacing.lg)
    }

    private func weekday(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: date)
    }
}
