import XCTest
@testable import WatchBridge

final class OutboxTests: XCTestCase {
    private var tempDir: URL!
    private var outbox: SetLogOutbox!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("outbox-\(UUID())")
        outbox = SetLogOutbox(directory: tempDir)
    }
    override func tearDown() { try? FileManager.default.removeItem(at: tempDir) }

    func test_emptyOnInit() throws {
        XCTAssertEqual(try outbox.pending().count, 0)
    }

    func test_enqueue_persists() throws {
        let log = SetLogDTO(sessionID: UUID(), exerciseID: "e", setNum: 1,
            reps: 5, load: "100", rpe: nil, loggedAt: Date(timeIntervalSince1970: 0))
        try outbox.enqueue(log)
        let reloaded = SetLogOutbox(directory: tempDir)
        XCTAssertEqual(try reloaded.pending(), [log])
    }

    func test_enqueue_dedupesOnNaturalKey() throws {
        let log1 = SetLogDTO(sessionID: UUID(), exerciseID: "e", setNum: 1,
            reps: 5, load: "100", rpe: nil, loggedAt: Date(timeIntervalSince1970: 0))
        let log2 = SetLogDTO(sessionID: log1.sessionID, exerciseID: "e", setNum: 1,
            reps: 7, load: "100", rpe: 8, loggedAt: Date(timeIntervalSince1970: 1))
        try outbox.enqueue(log1)
        try outbox.enqueue(log2)
        // Latest write wins — natural key is the dedup key.
        XCTAssertEqual(try outbox.pending(), [log2])
    }

    func test_drain_removesByKey() throws {
        let log = SetLogDTO(sessionID: UUID(), exerciseID: "e", setNum: 1,
            reps: 5, load: "100", rpe: nil, loggedAt: Date(timeIntervalSince1970: 0))
        try outbox.enqueue(log)
        try outbox.drain(naturalKey: log.naturalKey)
        XCTAssertEqual(try outbox.pending().count, 0)
    }

    func test_pending_isInsertionOrdered() throws {
        let s = UUID()
        let a = SetLogDTO(sessionID: s, exerciseID: "a", setNum: 1, reps: 5, load: "0", rpe: nil, loggedAt: Date(timeIntervalSince1970: 0))
        let b = SetLogDTO(sessionID: s, exerciseID: "b", setNum: 1, reps: 5, load: "0", rpe: nil, loggedAt: Date(timeIntervalSince1970: 1))
        try outbox.enqueue(a); try outbox.enqueue(b)
        XCTAssertEqual(try outbox.pending(), [a, b])
    }
}
