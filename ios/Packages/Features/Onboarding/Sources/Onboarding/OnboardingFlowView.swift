import SwiftUI
import CoreModels
import DesignSystem
import Repositories

public struct OnboardingFlowView: View {
    @State private var store: OnboardingStore
    @State private var healthConnected = false
    private let profileRepo: ProfileRepository
    private let themeStore: ThemeStore
    private let onComplete: (Profile) async -> Void

    public init(profileRepo: ProfileRepository,
                themeStore: ThemeStore,
                onComplete: @escaping (Profile) async -> Void) {
        self.profileRepo = profileRepo
        self.themeStore = themeStore
        self.onComplete = onComplete
        _store = State(initialValue: OnboardingStore())
    }

    public var body: some View {
        VStack(spacing: 0) {
            progressBar
            stepContent
            footer
        }
        .background(PulseColors.bg0.color.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onChange(of: store.draft.activeCoachID) { _, newID in
            if let id = newID {
                themeStore.setActiveCoach(id: id)
            }
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(PulseColors.bg2.color)
                Rectangle()
                    .fill(themeStore.accent.base.color)
                    .frame(width: geo.size.width * store.progress)
                    .animation(.spring(duration: 0.3), value: store.progress)
            }
        }
        .frame(height: 4)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch store.currentStep {
        case .name:      NameStepView(displayName: $store.draft.displayName)
        case .goals:     GoalsStepView(goals: $store.draft.goals)
        case .level:     LevelStepView(level: $store.draft.level)
        case .equipment: EquipmentStepView(equipment: $store.draft.equipment)
        case .frequency:
            FrequencyStepView(frequencyPerWeek: $store.draft.frequencyPerWeek,
                              weeklyTargetMinutes: $store.draft.weeklyTargetMinutes)
        case .coach:     CoachPickStepView(activeCoachID: $store.draft.activeCoachID)
        case .health:    HealthStepView(didConnect: $healthConnected)
        }
    }

    private var footer: some View {
        HStack {
            if store.currentStep != .name {
                PulseButton("Back", variant: .ghost) { store.back() }
            }
            Spacer()
            PulseButton(
                footerCTALabel,
                variant: .primary
            ) {
                if store.isAtFinalStep {
                    Task { await complete() }
                } else {
                    store.advance()
                }
            }
            .disabled(!store.canAdvanceFromCurrent)
        }
        .padding(PulseSpacing.lg)
    }

    private var footerCTALabel: String {
        if store.isAtFinalStep {
            return healthConnected ? "Generate my first workout" : "Skip & generate workout"
        }
        return "Next"
    }

    private func complete() async {
        guard let profile = store.draft.buildProfile(now: Date()) else { return }
        do {
            try profileRepo.save(profile)
            await onComplete(profile)
        } catch {
            // Plan 3 surfaces this via the global error alert; defer the alert
            // wiring to AppShell. Swallow here — onComplete is the side effect.
        }
    }
}
