import XCTest
import CoreModels
@testable import Complete

final class CompleteStoreTests: XCTestCase {
    @MainActor
    func test_feedbackDraft_cannotSubmitWhenRatingIsZero() {
        let store = CompleteStore()
        XCTAssertFalse(store.feedbackDraft.canSubmit)
        store.feedbackDraft.rating = 1
        XCTAssertTrue(store.feedbackDraft.canSubmit)
    }

    @MainActor
    func test_thumbsRoundTrip_setUnsetReplace() {
        let store = CompleteStore()
        store.feedbackDraft.exerciseRatings["e1"] = .up
        XCTAssertEqual(store.feedbackDraft.exerciseRatings["e1"], .up)
        store.feedbackDraft.exerciseRatings["e1"] = .down
        XCTAssertEqual(store.feedbackDraft.exerciseRatings["e1"], .down)
        store.feedbackDraft.exerciseRatings.removeValue(forKey: "e1")
        XCTAssertNil(store.feedbackDraft.exerciseRatings["e1"])
    }

    @MainActor
    func test_step_navigatesRecapToRateToAdaptation() {
        let store = CompleteStore()
        XCTAssertEqual(store.step, .recap)
        store.goToRate()
        XCTAssertEqual(store.step, .rate)
        store.goToAdaptation()
        XCTAssertEqual(store.step, .adaptation)
    }
}
