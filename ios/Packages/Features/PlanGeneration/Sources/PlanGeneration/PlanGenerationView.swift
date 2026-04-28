import SwiftUI
import CoreModels
import DesignSystem
import Repositories

public struct PlanGenerationView: View {
    @State private var store: PlanGenStore
    private let profile: Profile
    private let onViewWorkout: (UUID) -> Void
    private let onBackToHome: () -> Void

    public init(profile: Profile,
                coach: Coach,
                mode: PlanGenMode,
                streamProvider: @escaping PlanGenStore.StreamProvider,
                onPersistedWorkout: @escaping PlanGenStore.OnPersistedWorkout,
                onViewWorkout: @escaping (UUID) -> Void,
                onBackToHome: @escaping () -> Void) {
        self.profile = profile
        self.onViewWorkout = onViewWorkout
        self.onBackToHome = onBackToHome
        _store = State(initialValue: PlanGenStore(
            coach: coach, mode: mode,
            streamProvider: streamProvider,
            onPersistedWorkout: onPersistedWorkout
        ))
    }

    public var body: some View {
        ZStack {
            PulseColors.bg0.color.ignoresSafeArea()
            VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                header
                content
                Spacer()
            }
            .padding(PulseSpacing.lg)
        }
        .preferredColorScheme(.dark)
        .task { await store.run(profile: profile) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            Text(CoachStrings.planGenHeader(for: store.coach.id))
                .pulseFont(.h1)
                .foregroundStyle(PulseColors.ink0.color)
            Text(store.mode == .firstPlan ? "First day" : "Today's plan")
                .pulseFont(.small)
                .foregroundStyle(PulseColors.ink2.color)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store.state {
        case .streaming(let checkpoints, let text, _):
            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                ForEach(Array(checkpoints.enumerated()), id: \.offset) { _, cp in
                    CheckpointRowView(label: cp)
                }
                if !text.isEmpty {
                    StreamingTextPaneView(text: text)
                }
            }
        case .done(let handle):
            PlanGenDoneCardView(title: handle.title) {
                onViewWorkout(handle.id)
            }
        case .failed(let err):
            failedView(error: err)
        }
    }

    @ViewBuilder
    private func failedView(error: Error) -> some View {
        PulseCard {
            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                Text("Generation failed")
                    .pulseFont(.h2)
                    .foregroundStyle(PulseColors.ink0.color)
                Text(error.localizedDescription)
                    .pulseFont(.small)
                    .foregroundStyle(PulseColors.ink2.color)
                HStack {
                    PulseButton("Retry", variant: .primary) {
                        Task { await store.retry(profile: profile) }
                    }
                    PulseButton("Back to home", variant: .ghost, action: onBackToHome)
                }
            }
        }
    }
}
