import XCTest
import CoreModels
@testable import Onboarding

@MainActor
final class OnboardingStoreTests: XCTestCase {
    func test_initialState_atFirstStep() {
        let store = OnboardingStore()
        XCTAssertEqual(store.currentStep, .name)
        XCTAssertFalse(store.canAdvanceFromCurrent)
    }

    func test_advance_movesToNextStep() {
        let store = OnboardingStore()
        store.draft.displayName = "Sam"
        XCTAssertTrue(store.canAdvanceFromCurrent)
        store.advance()
        XCTAssertEqual(store.currentStep, .goals)
    }

    func test_advance_isNoOpWhenCannotAdvance() {
        let store = OnboardingStore()
        store.advance()
        XCTAssertEqual(store.currentStep, .name)
    }

    func test_back_movesToPreviousStep() {
        let store = OnboardingStore()
        store.draft.displayName = "Sam"
        store.advance()
        store.back()
        XCTAssertEqual(store.currentStep, .name)
    }

    func test_back_isNoOpAtFirstStep() {
        let store = OnboardingStore()
        store.back()
        XCTAssertEqual(store.currentStep, .name)
    }

    func test_progress_returnsFractionOfCompletedSteps() {
        let store = OnboardingStore()
        XCTAssertEqual(store.progress, 1.0 / 7.0, accuracy: 0.001)
        store.draft.displayName = "Sam"
        store.advance()
        XCTAssertEqual(store.progress, 2.0 / 7.0, accuracy: 0.001)
    }

    @MainActor
    func test_advance_fromCoachGoesToHealth() {
        let store = OnboardingStore()
        store.draft.displayName = "Sam"
        store.draft.goals = ["build muscle"]
        store.draft.level = .regular
        store.draft.equipment = ["dumbbells"]
        store.draft.frequencyPerWeek = 4
        store.draft.weeklyTargetMinutes = 180
        store.draft.activeCoachID = "rex"
        // Walk to .coach step
        while store.currentStep != .coach { store.advance() }
        XCTAssertFalse(store.isAtFinalStep)
        store.advance()
        XCTAssertEqual(store.currentStep, .health)
        XCTAssertTrue(store.isAtFinalStep)
        XCTAssertTrue(store.canAdvanceFromCurrent)
    }
}
