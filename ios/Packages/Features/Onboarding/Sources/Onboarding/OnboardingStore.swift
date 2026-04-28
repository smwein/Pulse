import Foundation
import Observation
import CoreModels

@MainActor
@Observable
public final class OnboardingStore {
    public var draft: OnboardingDraft
    public private(set) var currentStep: OnboardingDraft.Step

    public init(initialDraft: OnboardingDraft = OnboardingDraft()) {
        self.draft = initialDraft
        self.currentStep = .name
    }

    public var canAdvanceFromCurrent: Bool {
        draft.canAdvance(from: currentStep)
    }

    public var progress: Double {
        Double(currentStep.rawValue) / Double(OnboardingDraft.Step.allCases.count)
    }

    public func advance() {
        guard canAdvanceFromCurrent else { return }
        if let next = OnboardingDraft.Step(rawValue: currentStep.rawValue + 1) {
            currentStep = next
        }
    }

    public func back() {
        if let prev = OnboardingDraft.Step(rawValue: currentStep.rawValue - 1) {
            currentStep = prev
        }
    }

    public var isAtCoachStep: Bool { currentStep == .coach }
}
