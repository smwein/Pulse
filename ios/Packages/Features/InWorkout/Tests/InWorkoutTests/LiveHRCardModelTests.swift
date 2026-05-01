import XCTest
@testable import InWorkout

@MainActor
final class LiveHRCardModelTests: XCTestCase {
    func test_displayBPM_isNilOnFreshInit() {
        let m = LiveHRCardModel(now: { Date(timeIntervalSince1970: 0) })
        XCTAssertNil(m.displayBPM)
    }
    func test_record_setsBPM() {
        let m = LiveHRCardModel(now: { Date(timeIntervalSince1970: 100) })
        m.record(bpm: 80, at: Date(timeIntervalSince1970: 100))
        XCTAssertEqual(m.displayBPM, 80)
    }
    func test_record_smoothsOver5sWindow() {
        var t = Date(timeIntervalSince1970: 100)
        let m = LiveHRCardModel(now: { t })
        m.record(bpm: 70, at: t)
        t = Date(timeIntervalSince1970: 102)
        m.record(bpm: 80, at: t)
        t = Date(timeIntervalSince1970: 104)
        m.record(bpm: 90, at: t)
        XCTAssertEqual(m.displayBPM, 80)
    }
    func test_displayBPM_goesNilAfter10sStale() {
        var t = Date(timeIntervalSince1970: 100)
        let m = LiveHRCardModel(now: { t })
        m.record(bpm: 80, at: t)
        XCTAssertEqual(m.displayBPM, 80)
        t = Date(timeIntervalSince1970: 111)
        XCTAssertNil(m.displayBPM)
    }
}
