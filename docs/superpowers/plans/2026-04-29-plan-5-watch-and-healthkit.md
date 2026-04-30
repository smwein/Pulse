# Plan 5 — Watch + HealthKit Write + Live HR + Resume — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the Apple Watch app, the HealthKit write path, the WatchConnectivity bridge, the live HR card on Phone during workouts, and silent mid-session crash resume.

**Architecture:** Approach A from the spec — `HKWorkoutSession.startMirroringToCompanionDevice()` carries session lifecycle and live HR; `WCSession.transferUserInfo` carries the workout payload (Phone→Watch) and set logs (Watch→Phone) reliably; an idempotent repository write deduplicates set logs against the existing `(sessionID, exerciseID, setNum)` upsert. A new `Logging` package replaces Plan 4's silent catches.

**Tech Stack:** Swift 5.9, SwiftUI, SwiftData, async/await, HealthKit, WatchConnectivity, XCTest, XcodeGen (`Project.yml`).

**Spec:** `docs/superpowers/specs/2026-04-29-plan-5-design.md`

**Master spec:** `docs/superpowers/specs/2026-04-26-pulse-ai-trainer-app-design.md`

---

## Pre-flight notes for the implementing engineer

- The codebase uses **XcodeGen** — `ios/Project.yml` is the source of truth. After editing `Project.yml`, regenerate with `cd ios && xcodegen generate`.
- All packages use `swift test` for unit tests; Xcode runs the same suites.
- SwiftData transactions go through `ctx.atomicWrite { ... }` (not `transaction` — it collides with the SDK). See `Persistence/Transaction.swift`.
- SourceKit indexer occasionally false-positives "No such module 'X'" in editor — actual builds via `swift test` or `xcodebuild` are clean. Trust the build, not the squiggles.
- Existing `SessionRepository.logSet(sessionID:exerciseID:setNum:reps:load:rpe:now:)` is already an upsert keyed on `(sessionID, exerciseID, setNum)`. The idempotency-on-`setId` mentioned in the spec is satisfied by this existing key — **no separate UUID needed**, the wire DTO carries the natural key.
- `SessionEntity.watchSessionUUID: UUID?` already exists in `Persistence/Entities/SessionEntity.swift`. Plan 5 just starts populating it.
- Plan 4's orphan cleanup runs in `AppShell/FirstRunGate.checkFirstRun()` lines 103-107. Plan 5 modifies that gate.
- Commit style: `feat(scope):`, `test(scope):`, `chore(scope):`, `fix(scope):`, `refactor(scope):` with trailing `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`.
- Commit cadence: one commit per task, atomic, never amend.
- TDD where the unit is testable against a protocol fake. SwiftUI views get a `SmokeTests.swift` smoke (compiles + renders).
- **Test-scaffold reuse:** Some tasks reference helpers from Plan 4 tests (e.g., `makeStoreWithStartedSession`, `fetchSetLogs`, fake HKHealthStore). Inspect `ios/Packages/Features/InWorkout/Tests/InWorkoutTests/SessionStoreTests.swift` and `ios/Packages/HealthKitClient/Tests/` first; promote helpers to a shared test-support file (or duplicate them once) rather than starting from scratch.
- **Plan 4 store member names:** Tasks in Task Group 9 reference store members like `currentWorkout`, `activeSessionID`, and `sessionRepo`. Open the existing `SessionStore.swift` and adapt to the actual property names before writing the impl — these are conceptual placeholders pointing at "the Plan 4 equivalent".
- Real-device smoke is the ship gate — see Task Group 17.

---

# Task Group 0 — `Logging` package (Plan 4 forward-flag close-out)

This is the smallest dependency-free brick; build it first so later tasks can `import Logging`.

### Task 0.1: Create `Logging` package skeleton

**Files:**
- Create: `ios/Packages/Logging/Package.swift`
- Create: `ios/Packages/Logging/Sources/Logging/PulseLogger.swift`
- Create: `ios/Packages/Logging/Tests/LoggingTests/SmokeTests.swift`

- [ ] **Step 1: Create `Package.swift`**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Logging",
    platforms: [.iOS(.v17), .watchOS(.v10), .macOS(.v14)],
    products: [
        .library(name: "Logging", targets: ["Logging"])
    ],
    targets: [
        .target(name: "Logging", path: "Sources/Logging"),
        .testTarget(name: "LoggingTests", dependencies: ["Logging"], path: "Tests/LoggingTests")
    ]
)
```

- [ ] **Step 2: Add `Logging:` entry to `ios/Project.yml`**

Modify: `ios/Project.yml` — under `packages:` add:
```yaml
  Logging:
    path: Packages/Logging
```

- [ ] **Step 3: Stub `PulseLogger.swift` with smoke source**

```swift
import Foundation

public enum PulseLogger {
    public static let placeholder = "Logging package alive"
}
```

- [ ] **Step 4: Write smoke test**

```swift
import XCTest
@testable import Logging

final class LoggingSmokeTests: XCTestCase {
    func test_packageBuilds() {
        XCTAssertEqual(PulseLogger.placeholder, "Logging package alive")
    }
}
```

- [ ] **Step 5: Run smoke test**

Run: `cd ios/Packages/Logging && swift test`
Expected: `Test Suite 'LoggingTests' passed`. 1 test.

- [ ] **Step 6: Regenerate Xcode project**

Run: `cd ios && xcodegen generate`
Expected: project regenerates without warnings; `Logging` package visible in workspace.

- [ ] **Step 7: Commit**

```bash
git add ios/Packages/Logging ios/Project.yml ios/PulseApp.xcodeproj
git commit -m "$(cat <<'EOF'
chore(logging): scaffold Logging package

Empty-but-buildable Swift package for Plan 5's structured-logging work.
Replaces Plan 4 silent-catch sites in subsequent tasks.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 0.2: TDD `PulseLogger` API — categories + levels

**Files:**
- Modify: `ios/Packages/Logging/Sources/Logging/PulseLogger.swift`
- Create: `ios/Packages/Logging/Tests/LoggingTests/PulseLoggerTests.swift`

- [ ] **Step 1: Write failing test for category construction**

```swift
import XCTest
@testable import Logging

final class PulseLoggerTests: XCTestCase {
    func test_categoryLoggers_haveExpectedSubsystem() {
        XCTAssertEqual(PulseLogger.bridge.category, "bridge")
        XCTAssertEqual(PulseLogger.session.category, "session")
        XCTAssertEqual(PulseLogger.healthkit.category, "healthkit")
        XCTAssertEqual(PulseLogger.repo.category, "repo")
    }

    func test_subsystem_isPulseBundleID() {
        XCTAssertEqual(PulseLogger.bridge.subsystem, "co.simpleav.pulse")
    }
}
```

- [ ] **Step 2: Run — verify FAIL**

Run: `cd ios/Packages/Logging && swift test`
Expected: FAIL — `PulseLogger.bridge` undefined.

- [ ] **Step 3: Implement `PulseLogger`**

Replace `PulseLogger.swift`:
```swift
import Foundation
import os

/// Thin wrapper over `os.Logger` with pre-built category loggers.
/// Plan 7 will add a Sentry transport that observes `.error` and `.fault` levels.
public struct PulseLogger: Sendable {
    public let subsystem: String
    public let category: String
    private let backing: Logger

    public init(subsystem: String = "co.simpleav.pulse", category: String) {
        self.subsystem = subsystem
        self.category = category
        self.backing = Logger(subsystem: subsystem, category: category)
    }

    public func debug(_ message: String) { backing.debug("\(message, privacy: .public)") }
    public func info(_ message: String)  { backing.info("\(message, privacy: .public)") }
    public func notice(_ message: String){ backing.notice("\(message, privacy: .public)") }
    public func warning(_ message: String){ backing.warning("\(message, privacy: .public)") }
    public func error(_ message: String, _ error: Error? = nil) {
        if let error {
            backing.error("\(message, privacy: .public): \(String(describing: error), privacy: .public)")
        } else {
            backing.error("\(message, privacy: .public)")
        }
    }
    public func fault(_ message: String, _ error: Error? = nil) {
        if let error {
            backing.fault("\(message, privacy: .public): \(String(describing: error), privacy: .public)")
        } else {
            backing.fault("\(message, privacy: .public)")
        }
    }

    public static let bridge    = PulseLogger(category: "bridge")
    public static let session   = PulseLogger(category: "session")
    public static let healthkit = PulseLogger(category: "healthkit")
    public static let repo      = PulseLogger(category: "repo")
}
```

- [ ] **Step 4: Run — verify PASS**

Run: `cd ios/Packages/Logging && swift test`
Expected: 3 tests pass (smoke + 2 new).

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/Logging
git commit -m "$(cat <<'EOF'
feat(logging): PulseLogger wrapper with category subsystems

Categories: bridge, session, healthkit, repo. Tested category and subsystem
strings; emission shape verified by direct os.Logger pass-through.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 0.3: Replace silent catches in `Repositories` with `Logger.error`

**Files:**
- Modify: `ios/Packages/Repositories/Package.swift` (add Logging dep)
- Modify: `ios/Packages/Repositories/Sources/Repositories/PlanRepository.swift` (regenerate cleanup catch)
- Modify: `ios/Packages/Repositories/Sources/Repositories/SessionRepository.swift` (any silent catches)
- Modify: `ios/Packages/Repositories/Sources/Repositories/WorkoutRepository.swift` (any silent catches)

- [ ] **Step 1: Audit silent catches**

Run: `cd ios && grep -n "} catch {" Packages/Repositories/Sources/Repositories/*.swift`
List every line; the targets to replace are the `// best-effort` and similarly-comment-only catches called out in `plan-4-forward-flags.md`. Do NOT modify catches that intentionally surface errors via throw or return.

- [ ] **Step 2: Add `Logging` dep to `Repositories/Package.swift`**

Find the `dependencies:` array under `targets > .target(name: "Repositories", ...)` and add `.product(name: "Logging", package: "Logging")`. Add the matching package dep at top: `.package(name: "Logging", path: "../Logging")`.

- [ ] **Step 3: Replace each silent catch**

Pattern:
```swift
// before
do {
    // best-effort cleanup
    try someOperation()
} catch {
    // swallow
}

// after
do {
    try someOperation()
} catch {
    PulseLogger.repo.error("operation X failed during cleanup", error)
}
```

Apply to every instance found in Step 1. Do not change behavior; only log.

- [ ] **Step 4: Run repo tests**

Run: `cd ios/Packages/Repositories && swift test`
Expected: all existing tests still pass. No new tests required (logging is observability, not behavior).

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/Repositories
git commit -m "$(cat <<'EOF'
refactor(repo): replace silent catches with PulseLogger.error

Closes the Plan 4 forward-flag for unobservable cleanup-catch sites.
Behavior unchanged; previously-swallowed errors now log via
os.Logger under the 'repo' category. Sentry hookup will land in
Plan 7 by adding a transport — no caller changes needed then.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

# Task Group 1 — `WatchBridge` package: wire types

Define the cross-platform DTO and message envelope. Pure value types, fully testable via codec round-trip.

### Task 1.1: Create `WatchBridge` package skeleton (multi-platform)

**Files:**
- Create: `ios/Packages/WatchBridge/Package.swift`
- Create: `ios/Packages/WatchBridge/Sources/WatchBridge/WatchBridge.swift`
- Create: `ios/Packages/WatchBridge/Tests/WatchBridgeTests/SmokeTests.swift`

- [ ] **Step 1: `Package.swift`**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WatchBridge",
    platforms: [.iOS(.v17), .watchOS(.v10), .macOS(.v14)],
    products: [
        .library(name: "WatchBridge", targets: ["WatchBridge"])
    ],
    dependencies: [
        .package(name: "Logging", path: "../Logging"),
        .package(name: "CoreModels", path: "../CoreModels")
    ],
    targets: [
        .target(name: "WatchBridge",
                dependencies: [
                    .product(name: "Logging", package: "Logging"),
                    .product(name: "CoreModels", package: "CoreModels")
                ],
                path: "Sources/WatchBridge"),
        .testTarget(name: "WatchBridgeTests",
                    dependencies: ["WatchBridge"],
                    path: "Tests/WatchBridgeTests")
    ]
)
```

- [ ] **Step 2: Stub `WatchBridge.swift`**

```swift
import Foundation

public enum WatchBridge {
    public static let placeholder = "WatchBridge alive"
}
```

- [ ] **Step 3: Smoke test**

```swift
import XCTest
@testable import WatchBridge

final class WatchBridgeSmokeTests: XCTestCase {
    func test_packageBuilds() {
        XCTAssertEqual(WatchBridge.placeholder, "WatchBridge alive")
    }
}
```

- [ ] **Step 4: Add to `Project.yml` `packages:`**

```yaml
  WatchBridge:
    path: Packages/WatchBridge
```

- [ ] **Step 5: Run + regenerate**

Run: `cd ios/Packages/WatchBridge && swift test && cd ../../ && xcodegen generate`
Expected: smoke green, project regenerates.

- [ ] **Step 6: Commit**

```bash
git add ios/Packages/WatchBridge ios/Project.yml ios/PulseApp.xcodeproj
git commit -m "chore(bridge): scaffold WatchBridge package

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 1.2: TDD `WorkoutPayloadDTO` — Phone→Watch payload

**Files:**
- Create: `ios/Packages/WatchBridge/Sources/WatchBridge/WorkoutPayloadDTO.swift`
- Create: `ios/Packages/WatchBridge/Tests/WatchBridgeTests/WorkoutPayloadDTOTests.swift`

- [ ] **Step 1: Failing test for codec round-trip**

```swift
import XCTest
@testable import WatchBridge

final class WorkoutPayloadDTOTests: XCTestCase {
    func test_codec_roundTrip() throws {
        let original = WorkoutPayloadDTO(
            sessionID: UUID(),
            workoutID: UUID(),
            title: "Pull A",
            activityKind: "traditionalStrengthTraining",
            exercises: [
                .init(exerciseID: "barbell-row", name: "Barbell Row",
                      sets: [
                        .init(setNum: 1, prescribedReps: 8, prescribedLoad: "135"),
                        .init(setNum: 2, prescribedReps: 8, prescribedLoad: "135")
                      ])
            ]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WorkoutPayloadDTO.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}
```

- [ ] **Step 2: Run — verify FAIL**

Run: `cd ios/Packages/WatchBridge && swift test`
Expected: FAIL — type undefined.

- [ ] **Step 3: Implement DTO**

Create `WorkoutPayloadDTO.swift`:
```swift
import Foundation

public struct WorkoutPayloadDTO: Codable, Equatable, Sendable {
    public let sessionID: UUID
    public let workoutID: UUID
    public let title: String
    /// Mirrors HKWorkoutActivityType raw string so Watch can derive the activity type.
    public let activityKind: String
    public let exercises: [Exercise]

    public struct Exercise: Codable, Equatable, Sendable {
        public let exerciseID: String
        public let name: String
        public let sets: [SetPrescription]
        public init(exerciseID: String, name: String, sets: [SetPrescription]) {
            self.exerciseID = exerciseID; self.name = name; self.sets = sets
        }
    }

    public struct SetPrescription: Codable, Equatable, Sendable {
        public let setNum: Int
        public let prescribedReps: Int
        public let prescribedLoad: String
        public init(setNum: Int, prescribedReps: Int, prescribedLoad: String) {
            self.setNum = setNum; self.prescribedReps = prescribedReps; self.prescribedLoad = prescribedLoad
        }
    }

    public init(sessionID: UUID, workoutID: UUID, title: String,
                activityKind: String, exercises: [Exercise]) {
        self.sessionID = sessionID; self.workoutID = workoutID
        self.title = title; self.activityKind = activityKind; self.exercises = exercises
    }
}
```

- [ ] **Step 4: Run — verify PASS**

Run: `cd ios/Packages/WatchBridge && swift test`
Expected: round-trip green.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/WatchBridge
git commit -m "feat(bridge): WorkoutPayloadDTO with codec round-trip test

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 1.3: TDD `SetLogDTO`

**Files:**
- Create: `ios/Packages/WatchBridge/Sources/WatchBridge/SetLogDTO.swift`
- Create: `ios/Packages/WatchBridge/Tests/WatchBridgeTests/SetLogDTOTests.swift`

- [ ] **Step 1: Failing test**

```swift
import XCTest
@testable import WatchBridge

final class SetLogDTOTests: XCTestCase {
    func test_codec_roundTrip() throws {
        let original = SetLogDTO(
            sessionID: UUID(),
            exerciseID: "barbell-row",
            setNum: 2,
            reps: 8,
            load: "135",
            rpe: nil,
            loggedAt: Date(timeIntervalSince1970: 1_750_000_000)
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SetLogDTO.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func test_naturalKey_combinesSessionAndExerciseAndSetNum() {
        let dto = SetLogDTO(sessionID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                            exerciseID: "row", setNum: 3, reps: 5, load: "100",
                            rpe: nil, loggedAt: Date())
        XCTAssertEqual(dto.naturalKey, "00000000-0000-0000-0000-000000000001|row|3")
    }
}
```

- [ ] **Step 2: Run — verify FAIL**

Run: `cd ios/Packages/WatchBridge && swift test`

- [ ] **Step 3: Implement**

```swift
import Foundation

public struct SetLogDTO: Codable, Equatable, Sendable {
    public let sessionID: UUID
    public let exerciseID: String
    public let setNum: Int
    public let reps: Int
    public let load: String
    public let rpe: Int?
    public let loggedAt: Date

    public init(sessionID: UUID, exerciseID: String, setNum: Int, reps: Int,
                load: String, rpe: Int?, loggedAt: Date) {
        self.sessionID = sessionID; self.exerciseID = exerciseID; self.setNum = setNum
        self.reps = reps; self.load = load; self.rpe = rpe; self.loggedAt = loggedAt
    }

    /// Idempotency key — matches `SessionRepository.logSet`'s upsert key.
    public var naturalKey: String {
        "\(sessionID.uuidString)|\(exerciseID)|\(setNum)"
    }
}
```

- [ ] **Step 4: Run — verify PASS**

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/WatchBridge
git commit -m "feat(bridge): SetLogDTO with naturalKey idempotency derivation

Natural key matches SessionRepository.logSet upsert key
(sessionID, exerciseID, setNum) — no separate setId UUID needed.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 1.4: TDD `LifecycleEvent`

**Files:**
- Create: `ios/Packages/WatchBridge/Sources/WatchBridge/LifecycleEvent.swift`
- Create: `ios/Packages/WatchBridge/Tests/WatchBridgeTests/LifecycleEventTests.swift`

- [ ] **Step 1: Failing test**

```swift
import XCTest
@testable import WatchBridge

final class LifecycleEventTests: XCTestCase {
    func test_started_codec() throws {
        let uuid = UUID()
        let event = LifecycleEvent.started(watchSessionUUID: uuid)
        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(LifecycleEvent.self, from: data)
        XCTAssertEqual(event, decoded)
    }
    func test_ended_codec() throws {
        let event = LifecycleEvent.ended
        let data = try JSONEncoder().encode(event)
        XCTAssertEqual(try JSONDecoder().decode(LifecycleEvent.self, from: data), event)
    }
    func test_failed_codec_allReasons() throws {
        for r in LifecycleEvent.FailureReason.allCases {
            let event = LifecycleEvent.failed(reason: r)
            let data = try JSONEncoder().encode(event)
            XCTAssertEqual(try JSONDecoder().decode(LifecycleEvent.self, from: data), event)
        }
    }
}
```

- [ ] **Step 2: Run — verify FAIL**

- [ ] **Step 3: Implement**

```swift
import Foundation

public enum LifecycleEvent: Codable, Equatable, Sendable {
    case started(watchSessionUUID: UUID)
    case ended
    case failed(reason: FailureReason)

    public enum FailureReason: String, Codable, CaseIterable, Sendable {
        case healthKitDenied
        case sessionStartFailed
        case payloadInvalid
    }
}
```

- [ ] **Step 4: Run — verify PASS**

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/WatchBridge
git commit -m "feat(bridge): LifecycleEvent enum with FailureReason cases

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 1.5: TDD `WCMessage` envelope (single Codable across all transports)

**Files:**
- Create: `ios/Packages/WatchBridge/Sources/WatchBridge/WCMessage.swift`
- Create: `ios/Packages/WatchBridge/Tests/WatchBridgeTests/WCMessageTests.swift`

- [ ] **Step 1: Failing test — every variant round-trips**

```swift
import XCTest
@testable import WatchBridge

final class WCMessageTests: XCTestCase {
    func test_workoutPayload_roundTrip() throws {
        let payload = WorkoutPayloadDTO(sessionID: UUID(), workoutID: UUID(),
            title: "T", activityKind: "k", exercises: [])
        try assertRoundTrip(.workoutPayload(payload))
    }
    func test_setLog_roundTrip() throws {
        let log = SetLogDTO(sessionID: UUID(), exerciseID: "e", setNum: 1,
            reps: 5, load: "100", rpe: 7, loggedAt: Date(timeIntervalSince1970: 0))
        try assertRoundTrip(.setLog(log))
    }
    func test_sessionLifecycle_roundTrip() throws {
        try assertRoundTrip(.sessionLifecycle(.started(watchSessionUUID: UUID())))
        try assertRoundTrip(.sessionLifecycle(.ended))
        try assertRoundTrip(.sessionLifecycle(.failed(reason: .healthKitDenied)))
    }
    func test_ack_roundTrip() throws {
        try assertRoundTrip(.ack(naturalKey: "abc|row|1"))
    }

    private func assertRoundTrip(_ msg: WCMessage,
                                  file: StaticString = #file, line: UInt = #line) throws {
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(WCMessage.self, from: data)
        XCTAssertEqual(decoded, msg, file: file, line: line)
    }
}
```

- [ ] **Step 2: Run — verify FAIL**

- [ ] **Step 3: Implement**

```swift
import Foundation

public enum WCMessage: Codable, Equatable, Sendable {
    case workoutPayload(WorkoutPayloadDTO)
    case setLog(SetLogDTO)
    case sessionLifecycle(LifecycleEvent)
    case ack(naturalKey: String)
}
```

- [ ] **Step 4: Run — verify PASS**

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/WatchBridge
git commit -m "feat(bridge): WCMessage envelope enum with round-trip coverage

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 1.6: TDD JSON dictionary form for `WCSession.transferUserInfo`

`WCSession.transferUserInfo` takes a `[String: Any]` dict — not raw `Data`. Add `WCMessage.asUserInfo()` and `WCMessage(userInfo:)` round-trip via that representation.

**Files:**
- Modify: `ios/Packages/WatchBridge/Sources/WatchBridge/WCMessage.swift`
- Create: `ios/Packages/WatchBridge/Tests/WatchBridgeTests/WCMessageUserInfoTests.swift`

- [ ] **Step 1: Failing test**

```swift
import XCTest
@testable import WatchBridge

final class WCMessageUserInfoTests: XCTestCase {
    func test_userInfoRoundTrip_workoutPayload() throws {
        let payload = WorkoutPayloadDTO(sessionID: UUID(), workoutID: UUID(),
            title: "T", activityKind: "k", exercises: [])
        let msg = WCMessage.workoutPayload(payload)
        let userInfo = try msg.asUserInfo()
        let decoded = try WCMessage(userInfo: userInfo)
        XCTAssertEqual(decoded, msg)
    }
    func test_userInfoRoundTrip_setLog() throws {
        let log = SetLogDTO(sessionID: UUID(), exerciseID: "e", setNum: 1,
            reps: 5, load: "100", rpe: 7, loggedAt: Date(timeIntervalSince1970: 0))
        let msg = WCMessage.setLog(log)
        let userInfo = try msg.asUserInfo()
        XCTAssertEqual(try WCMessage(userInfo: userInfo), msg)
    }
    func test_userInfoMissingKey_throws() {
        XCTAssertThrowsError(try WCMessage(userInfo: ["nope": "x"]))
    }
}
```

- [ ] **Step 2: Run — verify FAIL**

- [ ] **Step 3: Add encode/decode helpers**

Append to `WCMessage.swift`:
```swift
public extension WCMessage {
    enum CodecError: Error { case missingPayload, invalidPayload }

    static let userInfoKey = "wcmsg.v1"

    func asUserInfo() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        return [Self.userInfoKey: data]
    }

    init(userInfo: [String: Any]) throws {
        guard let data = userInfo[Self.userInfoKey] as? Data else {
            throw CodecError.missingPayload
        }
        do {
            self = try JSONDecoder().decode(WCMessage.self, from: data)
        } catch {
            throw CodecError.invalidPayload
        }
    }
}
```

- [ ] **Step 4: Run — verify PASS**

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/WatchBridge
git commit -m "feat(bridge): WCMessage dict-form helpers for WCSession transferUserInfo

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

# Task Group 2 — `WatchBridge`: outbox + transport protocol

### Task 2.1: TDD `Outbox` JSON queue

The Watch outbox queues `SetLogDTO`s in a JSON file. Pure file I/O; testable on macOS.

**Files:**
- Create: `ios/Packages/WatchBridge/Sources/WatchBridge/Outbox.swift`
- Create: `ios/Packages/WatchBridge/Tests/WatchBridgeTests/OutboxTests.swift`

- [ ] **Step 1: Failing tests**

```swift
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
```

- [ ] **Step 2: Run — verify FAIL**

- [ ] **Step 3: Implement `SetLogOutbox`**

```swift
import Foundation

public final class SetLogOutbox: @unchecked Sendable {
    private let fileURL: URL
    private let queue = DispatchQueue(label: "co.simpleav.pulse.watchbridge.outbox")

    public init(directory: URL) {
        try? FileManager.default.createDirectory(at: directory,
                                                 withIntermediateDirectories: true)
        self.fileURL = directory.appendingPathComponent("pending-set-logs.json")
    }

    public func enqueue(_ log: SetLogDTO) throws {
        try queue.sync {
            var current = try loadLocked()
            current.removeAll { $0.naturalKey == log.naturalKey }
            current.append(log)
            try saveLocked(current)
        }
    }

    public func pending() throws -> [SetLogDTO] {
        try queue.sync { try loadLocked() }
    }

    public func drain(naturalKey: String) throws {
        try queue.sync {
            var current = try loadLocked()
            current.removeAll { $0.naturalKey == naturalKey }
            try saveLocked(current)
        }
    }

    private func loadLocked() throws -> [SetLogDTO] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([SetLogDTO].self, from: data)
    }
    private func saveLocked(_ logs: [SetLogDTO]) throws {
        let data = try JSONEncoder().encode(logs)
        try data.write(to: fileURL, options: .atomic)
    }
}
```

- [ ] **Step 4: Run — verify PASS**

Run: `cd ios/Packages/WatchBridge && swift test`
Expected: 5 outbox tests pass.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/WatchBridge
git commit -m "feat(bridge): SetLogOutbox JSON-backed queue with natural-key dedup

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 2.2: TDD `WatchSessionTransport` protocol + `FakeTransport`

Real `WCSession` is hostile to unit tests; introduce a protocol everything else codes against.

**Files:**
- Create: `ios/Packages/WatchBridge/Sources/WatchBridge/WatchSessionTransport.swift`
- Create: `ios/Packages/WatchBridge/Sources/WatchBridge/FakeTransport.swift`
- Create: `ios/Packages/WatchBridge/Tests/WatchBridgeTests/FakeTransportTests.swift`

- [ ] **Step 1: Failing test exercises the contract**

```swift
import XCTest
@testable import WatchBridge

final class FakeTransportTests: XCTestCase {
    func test_send_recordsInOrder() async throws {
        let t = FakeTransport()
        let log = SetLogDTO(sessionID: UUID(), exerciseID: "e", setNum: 1,
            reps: 5, load: "100", rpe: nil, loggedAt: Date(timeIntervalSince1970: 0))
        try await t.send(.setLog(log), via: .reliable)
        try await t.send(.sessionLifecycle(.ended), via: .live)
        XCTAssertEqual(t.sent.count, 2)
        XCTAssertEqual(t.sent[0].channel, .reliable)
        XCTAssertEqual(t.sent[1].channel, .live)
    }

    func test_inbox_publishesReceivedMessages() async throws {
        let t = FakeTransport()
        var received: [WCMessage] = []
        let task = Task {
            for await msg in await t.incoming { received.append(msg) }
        }
        await t.simulateIncoming(.sessionLifecycle(.ended))
        try await Task.sleep(nanoseconds: 10_000_000)
        task.cancel()
        XCTAssertEqual(received, [.sessionLifecycle(.ended)])
    }

    func test_isReachable_initiallyFalse() async {
        let t = FakeTransport()
        let r = await t.isReachable
        XCTAssertFalse(r)
    }
}
```

- [ ] **Step 2: Run — verify FAIL**

- [ ] **Step 3: Implement protocol + fake**

`WatchSessionTransport.swift`:
```swift
import Foundation

public enum WCChannel: Sendable, Equatable {
    case reliable   // transferUserInfo — queued, survives unreachability
    case live       // sendMessage — best-effort, requires reachability
}

public protocol WatchSessionTransport: Actor {
    var isReachable: Bool { get }
    var incoming: AsyncStream<WCMessage> { get }
    func send(_ message: WCMessage, via channel: WCChannel) async throws
}
```

`FakeTransport.swift`:
```swift
import Foundation

public actor FakeTransport: WatchSessionTransport {
    public struct Sent: Equatable, Sendable {
        public let message: WCMessage
        public let channel: WCChannel
    }

    public private(set) var sent: [Sent] = []
    public var reachable: Bool = false
    public var sendError: Error?

    public var isReachable: Bool { reachable }

    private var continuations: [AsyncStream<WCMessage>.Continuation] = []
    public var incoming: AsyncStream<WCMessage> {
        AsyncStream { cont in continuations.append(cont) }
    }

    public init() {}

    public func setReachable(_ v: Bool) { reachable = v }
    public func setSendError(_ e: Error?) { sendError = e }

    public func send(_ message: WCMessage, via channel: WCChannel) async throws {
        if let e = sendError { throw e }
        sent.append(Sent(message: message, channel: channel))
    }

    public func simulateIncoming(_ message: WCMessage) {
        for c in continuations { c.yield(message) }
    }
}
```

- [ ] **Step 4: Run — verify PASS**

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/WatchBridge
git commit -m "feat(bridge): WatchSessionTransport protocol + FakeTransport for tests

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 2.3: Implement `LiveWatchSessionTransport` (real WCSession wrapper)

Not unit-testable in the strict sense — verified via real-device smoke. Keep the surface minimal; all logic lives in `Outbox` + state stores.

**Files:**
- Create: `ios/Packages/WatchBridge/Sources/WatchBridge/LiveWatchSessionTransport.swift`

- [ ] **Step 1: Implement**

```swift
import Foundation
import Logging
#if canImport(WatchConnectivity)
import WatchConnectivity

public actor LiveWatchSessionTransport: NSObject, WatchSessionTransport, WCSessionDelegate {
    private var continuations: [AsyncStream<WCMessage>.Continuation] = []
    private let session: WCSession

    public var isReachable: Bool { session.isReachable }
    public var incoming: AsyncStream<WCMessage> {
        AsyncStream { cont in continuations.append(cont) }
    }

    public init(session: WCSession = .default) {
        self.session = session
        super.init()
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }

    public func send(_ message: WCMessage, via channel: WCChannel) async throws {
        let userInfo = try message.asUserInfo()
        switch channel {
        case .reliable:
            session.transferUserInfo(userInfo)
        case .live:
            guard session.isReachable else {
                // Live channel requires reachability; fall back to reliable.
                session.transferUserInfo(userInfo); return
            }
            session.sendMessage(userInfo, replyHandler: nil) { error in
                PulseLogger.bridge.error("sendMessage failed", error)
            }
        }
    }

    private func dispatch(_ msg: WCMessage) {
        for c in continuations { c.yield(msg) }
    }

    // MARK: WCSessionDelegate
    public nonisolated func session(_ session: WCSession,
                                    activationDidCompleteWith state: WCSessionActivationState,
                                    error: Error?) {
        if let error { PulseLogger.bridge.error("WCSession activation failed", error) }
    }
    public nonisolated func session(_ session: WCSession,
                                    didReceiveUserInfo userInfo: [String: Any] = [:]) {
        do {
            let msg = try WCMessage(userInfo: userInfo)
            Task { await self.dispatch(msg) }
        } catch {
            PulseLogger.bridge.error("WCMessage decode failed", error)
        }
    }
    public nonisolated func session(_ session: WCSession,
                                    didReceiveMessage message: [String: Any]) {
        do {
            let msg = try WCMessage(userInfo: message)
            Task { await self.dispatch(msg) }
        } catch {
            PulseLogger.bridge.error("WCMessage decode failed", error)
        }
    }
    #if os(iOS)
    public nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    public nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
#endif
```

- [ ] **Step 2: Build (no test — protocol fake handles unit tests)**

Run: `cd ios/Packages/WatchBridge && swift build`
Expected: builds for macOS without errors (the `#if canImport(WatchConnectivity)` guards macOS where WC isn't available).

- [ ] **Step 3: Commit**

```bash
git add ios/Packages/WatchBridge
git commit -m "feat(bridge): LiveWatchSessionTransport — WCSession wrapper

No unit tests — verified via real-device smoke. Logic stays in
Outbox + state stores; this is a thin pass-through.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

# Task Group 3 — `HealthKitClient`: write authorization

### Task 3.1: Extend `HKHealthStoreProtocol` for write share types

The existing protocol's `requestAuthorization(toShare:read:)` already accepts a `Set<HKSampleType>?` for share. The Plan 4 implementation passes `nil`. We just need a typed entry-point for write categories.

**Files:**
- Modify: `ios/Packages/HealthKitClient/Sources/HealthKitClient/HealthKitClient.swift`
- Create: `ios/Packages/HealthKitClient/Tests/HealthKitClientTests/WriteAuthTests.swift`

- [ ] **Step 1: Extend `HKHealthStoreProtocol` test fake**

Find the existing fake (referenced by Plan 4 tests). If it's defined in tests, extend it there. If not, search:
```
cd ios && grep -rn "HKHealthStoreProtocol" Packages/HealthKitClient/Tests
```
Modify the fake to record the most recent `toShare:` arg. Pseudocode:
```swift
final class FakeHKHealthStore: HKHealthStoreProtocol {
    var lastShareTypes: Set<HKSampleType>?
    var lastReadTypes: Set<HKObjectType>?
    func requestAuthorization(toShare typesToShare: Set<HKSampleType>?,
                              read typesToRead: Set<HKObjectType>?) async throws {
        lastShareTypes = typesToShare
        lastReadTypes = typesToRead
    }
    // ... existing samples(of:predicate:) impl
}
```

- [ ] **Step 2: Failing test for `requestWriteAuthorization()`**

`WriteAuthTests.swift`:
```swift
import XCTest
@testable import HealthKitClient
#if canImport(HealthKit)
import HealthKit

final class WriteAuthTests: XCTestCase {
    func test_requestWriteAuthorization_passesExpectedTypes() async throws {
        let fake = FakeHKHealthStore()  // from Plan 4 tests
        let client = HealthKitClient(store: fake)
        try await client.requestWriteAuthorization()
        let expected: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.heartRate),
        ]
        XCTAssertEqual(fake.lastShareTypes, expected)
    }
}
#endif
```

- [ ] **Step 3: Run — verify FAIL**

Run: `cd ios/Packages/HealthKitClient && swift test`
Expected: FAIL — `requestWriteAuthorization()` undefined.

- [ ] **Step 4: Implement on `HealthKitClient`**

Append to `HealthKitClient.swift`:
```swift
public extension HealthKitClient {
    func requestWriteAuthorization() async throws {
        #if canImport(HealthKit)
        guard let store else { return }
        let share: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.heartRate),
        ]
        try await store.requestAuthorization(toShare: share, read: nil)
        #endif
    }

    /// Returns true when *all* write categories are authorized.
    /// The HealthKit auth status is per-type; we treat partial as not-ready.
    func writeAuthorizationStatus() -> WriteAuthStatus {
        #if canImport(HealthKit)
        guard let store = store as? HKHealthStore else { return .undetermined }
        let types: [HKSampleType] = [
            HKObjectType.workoutType(),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.heartRate),
        ]
        let statuses = types.map { store.authorizationStatus(for: $0) }
        if statuses.allSatisfy({ $0 == .sharingAuthorized }) { return .authorized }
        if statuses.contains(.sharingDenied) { return .denied }
        return .undetermined
        #else
        return .undetermined
        #endif
    }
}

public enum WriteAuthStatus: Sendable, Equatable {
    case undetermined
    case authorized
    case denied
}
```

- [ ] **Step 5: Run — verify PASS**

- [ ] **Step 6: Commit**

```bash
git add ios/Packages/HealthKitClient
git commit -m "feat(healthkit): requestWriteAuthorization for HKWorkout + energy + HR

Plan 5 write categories: HKWorkoutType, activeEnergyBurned, heartRate.
Status check returns .authorized only when all three are .sharingAuthorized;
partial coverage maps to .undetermined.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

# Task Group 4 — Watch app target + `WatchWorkout` package skeleton

### Task 4.1: Create `Features/WatchWorkout` package skeleton (watchOS-only)

**Files:**
- Create: `ios/Packages/Features/WatchWorkout/Package.swift`
- Create: `ios/Packages/Features/WatchWorkout/Sources/WatchWorkout/Module.swift`
- Create: `ios/Packages/Features/WatchWorkout/Tests/WatchWorkoutTests/SmokeTests.swift`

- [ ] **Step 1: `Package.swift` (watchOS + macOS for tests)**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WatchWorkout",
    platforms: [.watchOS(.v10), .macOS(.v14)],
    products: [
        .library(name: "WatchWorkout", targets: ["WatchWorkout"])
    ],
    dependencies: [
        .package(name: "WatchBridge", path: "../../WatchBridge"),
        .package(name: "Logging", path: "../../Logging"),
        .package(name: "HealthKitClient", path: "../../HealthKitClient"),
        .package(name: "DesignSystem", path: "../../DesignSystem")
    ],
    targets: [
        .target(name: "WatchWorkout",
                dependencies: [
                    .product(name: "WatchBridge", package: "WatchBridge"),
                    .product(name: "Logging", package: "Logging"),
                    .product(name: "HealthKitClient", package: "HealthKitClient"),
                    .product(name: "DesignSystem", package: "DesignSystem")
                ],
                path: "Sources/WatchWorkout"),
        .testTarget(name: "WatchWorkoutTests",
                    dependencies: ["WatchWorkout"],
                    path: "Tests/WatchWorkoutTests")
    ]
)
```

- [ ] **Step 2: `Module.swift` stub**

```swift
import Foundation

public enum WatchWorkout {
    public static let placeholder = "WatchWorkout alive"
}
```

- [ ] **Step 3: Smoke test**

```swift
import XCTest
@testable import WatchWorkout

final class WatchWorkoutSmokeTests: XCTestCase {
    func test_packageBuilds() {
        XCTAssertEqual(WatchWorkout.placeholder, "WatchWorkout alive")
    }
}
```

- [ ] **Step 4: Add to `Project.yml` `packages:`**

```yaml
  WatchWorkout:
    path: Packages/Features/WatchWorkout
```

- [ ] **Step 5: Run — verify PASS**

Run: `cd ios/Packages/Features/WatchWorkout && swift test`
Expected: 1 test passes.

- [ ] **Step 6: Commit**

```bash
git add ios/Packages/Features/WatchWorkout ios/Project.yml
git commit -m "chore(watch): scaffold Features/WatchWorkout package

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 4.2: Add `PulseWatch` watchOS app target to `Project.yml`

**Files:**
- Modify: `ios/Project.yml`
- Create: `ios/PulseWatch/PulseWatchApp.swift`
- Create: `ios/PulseWatch/Info.plist`
- Create: `ios/PulseWatch/Assets.xcassets/AppIcon.appiconset/Contents.json`

- [ ] **Step 1: Append target to `Project.yml`**

Under `targets:`, append:
```yaml
  PulseWatch:
    type: application.watchapp2
    platform: watchOS
    deploymentTarget: "10.0"
    sources:
      - path: PulseWatch
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: co.simpleav.pulse.watchkitapp
        INFOPLIST_FILE: PulseWatch/Info.plist
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
        TARGETED_DEVICE_FAMILY: "4"
        ENABLE_PREVIEWS: YES
        WATCHOS_DEPLOYMENT_TARGET: "10.0"
        SWIFT_EMIT_LOC_STRINGS: YES
    dependencies:
      - package: CoreModels
      - package: DesignSystem
      - package: WatchBridge
      - package: WatchWorkout
      - package: HealthKitClient
      - package: Logging
```

(`application.watchapp2` is XcodeGen's name for a paired-companion watchOS app target, not the deprecated extension style.)

- [ ] **Step 2: `PulseWatchApp.swift` minimal entry**

```swift
import SwiftUI

@main
struct PulseWatchApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Pulse Watch — Plan 5 in progress")
        }
    }
}
```

- [ ] **Step 3: Minimal `Info.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>Pulse</string>
    <key>UIDeviceFamily</key>
    <array><integer>4</integer></array>
    <key>WKApplication</key>
    <true/>
    <key>WKBackgroundModes</key>
    <array><string>workout-processing</string></array>
    <key>NSHealthShareUsageDescription</key>
    <string>Pulse uses your heart rate during workouts to power the live HR display and adapt your plan.</string>
    <key>NSHealthUpdateUsageDescription</key>
    <string>Pulse saves completed workouts to Health so the AI can adapt your plan over time.</string>
</dict>
</plist>
```

- [ ] **Step 4: Empty AppIcon catalog**

`PulseWatch/Assets.xcassets/AppIcon.appiconset/Contents.json`:
```json
{
  "images" : [
    {
      "idiom" : "universal",
      "platform" : "watchos",
      "size" : "1024x1024"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

- [ ] **Step 5: Regenerate + build**

Run: `cd ios && xcodegen generate && xcodebuild -workspace PulseApp.xcodeproj/project.xcworkspace -scheme PulseWatch -destination 'generic/platform=watchOS' -configuration Debug build`
Expected: `BUILD SUCCEEDED`. (If the watchOS-sim destination is preferred and known, swap it in.)

- [ ] **Step 6: Commit**

```bash
git add ios/Project.yml ios/PulseWatch ios/PulseApp.xcodeproj
git commit -m "feat(watch): add PulseWatch watchOS app target

Skeleton paired-companion target with workout-processing background mode
and HealthKit share/update usage strings. Renders a placeholder view;
business logic lands in subsequent tasks.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

# Task Group 5 — Watch state machine + Idle screen

### Task 5.1: TDD `WatchSessionStore` initial state

The Watch's central state holder. Pure logic, fully testable.

**Files:**
- Create: `ios/Packages/Features/WatchWorkout/Sources/WatchWorkout/WatchSessionStore.swift`
- Create: `ios/Packages/Features/WatchWorkout/Tests/WatchWorkoutTests/WatchSessionStoreTests.swift`

- [ ] **Step 1: Failing test**

```swift
import XCTest
import WatchBridge
@testable import WatchWorkout

@MainActor
final class WatchSessionStoreTests: XCTestCase {
    func test_initialState_isIdle() async {
        let store = WatchSessionStore(transport: FakeTransport(),
                                      outbox: SetLogOutbox(directory: tempDir()),
                                      sessionFactory: FakeWorkoutSessionFactory())
        XCTAssertEqual(store.state, .idle)
        XCTAssertNil(store.payload)
    }

    private func tempDir() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("store-\(UUID())")
    }
}
```

The test references types that don't exist yet — that's the failing-test contract.

- [ ] **Step 2: Run — verify FAIL**

Run: `cd ios/Packages/Features/WatchWorkout && swift test`
Expected: FAIL — `WatchSessionStore`, `WatchSessionState`, `FakeWorkoutSessionFactory` undefined.

- [ ] **Step 3: Define state enum + factory protocol + skeleton store**

`WatchSessionStore.swift`:
```swift
import Foundation
import Observation
import WatchBridge
import Logging

public enum WatchSessionState: Equatable, Sendable {
    case idle
    case ready             // payload received, session not started
    case starting          // HKWorkoutSession start in flight
    case active            // session active, awaiting set confirmations
    case resting(setNum: Int, exerciseID: String)
    case ended
    case failed(reason: LifecycleEvent.FailureReason)
}

/// Indirection so tests don't need a real HKWorkoutSession.
public protocol WorkoutSessionFactory: Sendable {
    func startSession(activityKind: String) async throws -> UUID
    func endSession() async throws
    func recoverIfActive() async -> UUID?
}

@MainActor
@Observable
public final class WatchSessionStore {
    public private(set) var state: WatchSessionState = .idle
    public private(set) var payload: WorkoutPayloadDTO?
    public private(set) var watchSessionUUID: UUID?

    private let transport: any WatchSessionTransport
    private let outbox: SetLogOutbox
    private let factory: WorkoutSessionFactory

    public init(transport: any WatchSessionTransport,
                outbox: SetLogOutbox,
                sessionFactory: WorkoutSessionFactory) {
        self.transport = transport
        self.outbox = outbox
        self.factory = sessionFactory
    }
}

// Test-only fake factory lives in test target.
```

In test file `WatchSessionStoreTests.swift`, append:
```swift
final class FakeWorkoutSessionFactory: WorkoutSessionFactory {
    var startError: Error?
    var startedUUID = UUID()
    var ended = false
    var recoveredUUID: UUID?
    func startSession(activityKind: String) async throws -> UUID {
        if let e = startError { throw e }
        return startedUUID
    }
    func endSession() async throws { ended = true }
    func recoverIfActive() async -> UUID? { recoveredUUID }
}
```

- [ ] **Step 4: Run — verify PASS**

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/Features/WatchWorkout
git commit -m "feat(watch): WatchSessionStore skeleton with state machine

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 5.2: TDD `receivePayload(_:)` transitions to `.ready` and persists

**Files:**
- Modify: `ios/Packages/Features/WatchWorkout/Sources/WatchWorkout/WatchSessionStore.swift`
- Modify: `ios/Packages/Features/WatchWorkout/Tests/WatchWorkoutTests/WatchSessionStoreTests.swift`

- [ ] **Step 1: Failing test**

Append to `WatchSessionStoreTests`:
```swift
func test_receivePayload_setsReadyAndPersists() async throws {
    let dir = tempDir()
    let payload = WorkoutPayloadDTO(sessionID: UUID(), workoutID: UUID(),
        title: "Pull A", activityKind: "traditionalStrengthTraining", exercises: [])
    let store = WatchSessionStore(transport: FakeTransport(),
                                  outbox: SetLogOutbox(directory: dir),
                                  sessionFactory: FakeWorkoutSessionFactory(),
                                  payloadStorage: PayloadFileStorage(directory: dir))
    await store.receivePayload(payload)
    XCTAssertEqual(store.state, .ready)
    XCTAssertEqual(store.payload, payload)

    let url = dir.appendingPathComponent("active-workout-payload.json")
    let data = try Data(contentsOf: url)
    let reloaded = try JSONDecoder().decode(WorkoutPayloadDTO.self, from: data)
    XCTAssertEqual(reloaded, payload)
}
```

- [ ] **Step 2: Run — verify FAIL**

- [ ] **Step 3: Add `PayloadFileStorage` + extend store**

Add a new file `ios/Packages/Features/WatchWorkout/Sources/WatchWorkout/PayloadFileStorage.swift`:
```swift
import Foundation
import WatchBridge

public struct PayloadFileStorage: Sendable {
    public let url: URL
    public init(directory: URL) {
        try? FileManager.default.createDirectory(at: directory,
                                                 withIntermediateDirectories: true)
        self.url = directory.appendingPathComponent("active-workout-payload.json")
    }
    public func write(_ payload: WorkoutPayloadDTO) throws {
        let data = try JSONEncoder().encode(payload)
        try data.write(to: url, options: .atomic)
    }
    public func read() throws -> WorkoutPayloadDTO? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(WorkoutPayloadDTO.self, from: data)
    }
    public func clear() throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
```

Modify `WatchSessionStore.swift` init + add method:
```swift
private let payloadStorage: PayloadFileStorage

public init(transport: any WatchSessionTransport,
            outbox: SetLogOutbox,
            sessionFactory: WorkoutSessionFactory,
            payloadStorage: PayloadFileStorage = PayloadFileStorage(
                directory: FileManager.default.urls(for: .applicationSupportDirectory,
                                                    in: .userDomainMask)[0])) {
    self.transport = transport
    self.outbox = outbox
    self.factory = sessionFactory
    self.payloadStorage = payloadStorage
}

public func receivePayload(_ payload: WorkoutPayloadDTO) async {
    do {
        try payloadStorage.write(payload)
    } catch {
        PulseLogger.session.error("failed to persist payload", error)
    }
    self.payload = payload
    self.state = .ready
}
```

- [ ] **Step 4: Run — verify PASS**

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/Features/WatchWorkout
git commit -m "feat(watch): receivePayload — persist + transition to .ready

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 5.3: TDD `start()` transitions through `.starting` → `.active` and emits lifecycle

**Files:**
- Modify same store + tests

- [ ] **Step 1: Failing test**

```swift
func test_start_transitionsAndSendsLifecycle() async throws {
    let transport = FakeTransport()
    let factory = FakeWorkoutSessionFactory()
    let dir = tempDir()
    let payload = WorkoutPayloadDTO(sessionID: UUID(), workoutID: UUID(),
        title: "Pull A", activityKind: "traditionalStrengthTraining", exercises: [])
    let store = WatchSessionStore(transport: transport,
                                  outbox: SetLogOutbox(directory: dir),
                                  sessionFactory: factory,
                                  payloadStorage: PayloadFileStorage(directory: dir))
    await store.receivePayload(payload)
    try await store.start()
    XCTAssertEqual(store.state, .active)
    XCTAssertEqual(store.watchSessionUUID, factory.startedUUID)
    let sent = await transport.sent
    XCTAssertEqual(sent.count, 1)
    XCTAssertEqual(sent[0].channel, .live)
    if case .sessionLifecycle(.started(let uuid)) = sent[0].message {
        XCTAssertEqual(uuid, factory.startedUUID)
    } else {
        XCTFail("expected .sessionLifecycle(.started(...))")
    }
}

func test_start_failure_emitsFailedLifecycle() async throws {
    let transport = FakeTransport()
    let factory = FakeWorkoutSessionFactory()
    factory.startError = NSError(domain: "test", code: 1)
    let dir = tempDir()
    let payload = WorkoutPayloadDTO(sessionID: UUID(), workoutID: UUID(),
        title: "T", activityKind: "k", exercises: [])
    let store = WatchSessionStore(transport: transport,
                                  outbox: SetLogOutbox(directory: dir),
                                  sessionFactory: factory,
                                  payloadStorage: PayloadFileStorage(directory: dir))
    await store.receivePayload(payload)
    do {
        try await store.start()
        XCTFail("expected throw")
    } catch {}
    XCTAssertEqual(store.state, .failed(reason: .sessionStartFailed))
    let sent = await transport.sent
    XCTAssertEqual(sent.count, 1)
    XCTAssertEqual(sent[0].message, .sessionLifecycle(.failed(reason: .sessionStartFailed)))
}
```

- [ ] **Step 2: Run — verify FAIL**

- [ ] **Step 3: Implement**

Add to `WatchSessionStore.swift`:
```swift
public func start() async throws {
    guard let payload else { return }
    state = .starting
    do {
        let uuid = try await factory.startSession(activityKind: payload.activityKind)
        watchSessionUUID = uuid
        state = .active
        try await transport.send(.sessionLifecycle(.started(watchSessionUUID: uuid)),
                                 via: .live)
    } catch {
        state = .failed(reason: .sessionStartFailed)
        try? await transport.send(.sessionLifecycle(.failed(reason: .sessionStartFailed)),
                                  via: .live)
        throw error
    }
}
```

- [ ] **Step 4: Run — verify PASS**

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/Features/WatchWorkout
git commit -m "feat(watch): start() drives state machine + emits .sessionLifecycle

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 5.4: Build `IdleView` SwiftUI

**Files:**
- Create: `ios/Packages/Features/WatchWorkout/Sources/WatchWorkout/IdleView.swift`
- Modify smoke test to render it.

- [ ] **Step 1: View**

```swift
import SwiftUI
import WatchBridge

public struct IdleView: View {
    public let payload: WorkoutPayloadDTO?
    public let onStart: () -> Void
    public init(payload: WorkoutPayloadDTO?, onStart: @escaping () -> Void) {
        self.payload = payload; self.onStart = onStart
    }
    public var body: some View {
        VStack(spacing: 8) {
            if let p = payload {
                Text(p.title).font(.headline)
                Button("Start", action: onStart)
                    .buttonStyle(.borderedProminent)
            } else {
                Text("Waiting for phone…")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}
```

- [ ] **Step 2: Smoke test the view**

Append to `WatchWorkoutTests/SmokeTests.swift`:
```swift
import SwiftUI
@testable import WatchWorkout

func test_idleView_rendersBothStates() {
    let withPayload = IdleView(payload: WorkoutPayloadDTO(sessionID: UUID(),
        workoutID: UUID(), title: "T", activityKind: "k", exercises: []),
        onStart: {})
    let waiting = IdleView(payload: nil, onStart: {})
    _ = withPayload.body
    _ = waiting.body
}
```

(SwiftUI smoke tests in this codebase materialize `body` to confirm the view compiles + lays out at all.)

- [ ] **Step 3: Run + commit**

Run: `cd ios/Packages/Features/WatchWorkout && swift test`

```bash
git add ios/Packages/Features/WatchWorkout
git commit -m "feat(watch): IdleView — waiting / ready states

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

# Task Group 6 — Active Set screen + HKWorkoutSession start

### Task 6.1: TDD store helpers — `currentExercise`, `currentSetNum`

**Files:**
- Modify: `WatchSessionStore.swift` + tests

- [ ] **Step 1: Failing test**

```swift
func test_currentExercise_andSetNum_advanceWithLogs() async throws {
    let payload = WorkoutPayloadDTO(sessionID: UUID(), workoutID: UUID(),
        title: "T", activityKind: "k",
        exercises: [
            .init(exerciseID: "row", name: "Row", sets: [
                .init(setNum: 1, prescribedReps: 8, prescribedLoad: "100"),
                .init(setNum: 2, prescribedReps: 8, prescribedLoad: "100")
            ]),
            .init(exerciseID: "press", name: "Press", sets: [
                .init(setNum: 1, prescribedReps: 5, prescribedLoad: "60")
            ])
        ])
    let dir = tempDir()
    let store = WatchSessionStore(transport: FakeTransport(),
                                  outbox: SetLogOutbox(directory: dir),
                                  sessionFactory: FakeWorkoutSessionFactory(),
                                  payloadStorage: PayloadFileStorage(directory: dir))
    await store.receivePayload(payload)
    try await store.start()

    XCTAssertEqual(store.currentExerciseID, "row")
    XCTAssertEqual(store.currentSetNum, 1)

    await store.confirmCurrentSet()  // advances
    XCTAssertEqual(store.currentExerciseID, "row")
    XCTAssertEqual(store.currentSetNum, 2)

    await store.confirmCurrentSet()  // advances to next exercise
    XCTAssertEqual(store.currentExerciseID, "press")
    XCTAssertEqual(store.currentSetNum, 1)
}
```

- [ ] **Step 2: Run — verify FAIL**

- [ ] **Step 3: Implement**

Add to `WatchSessionStore.swift`:
```swift
private var loggedSetCounts: [String: Int] = [:]  // exerciseID → count

public var currentExerciseID: String? {
    guard let payload else { return nil }
    for ex in payload.exercises {
        let logged = loggedSetCounts[ex.exerciseID] ?? 0
        if logged < ex.sets.count { return ex.exerciseID }
    }
    return nil
}

public var currentSetNum: Int? {
    guard let id = currentExerciseID else { return nil }
    return (loggedSetCounts[id] ?? 0) + 1
}

public func confirmCurrentSet() async {
    guard let exID = currentExerciseID, let setNum = currentSetNum,
          let payload, let ex = payload.exercises.first(where: { $0.exerciseID == exID }),
          let prescription = ex.sets.first(where: { $0.setNum == setNum })
    else { return }
    let log = SetLogDTO(sessionID: payload.sessionID, exerciseID: exID, setNum: setNum,
                        reps: prescription.prescribedReps, load: prescription.prescribedLoad,
                        rpe: nil, loggedAt: Date())
    do { try outbox.enqueue(log) } catch {
        PulseLogger.session.error("outbox enqueue failed", error)
    }
    try? await transport.send(.setLog(log), via: .reliable)
    loggedSetCounts[exID, default: 0] += 1

    // Transition to rest unless this was the last set of the workout.
    if currentExerciseID == nil {
        // last set logged — caller should call endSession()
        state = .ended
    } else {
        state = .resting(setNum: setNum, exerciseID: exID)
    }
}
```

- [ ] **Step 4: Run — verify PASS**

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/Features/WatchWorkout
git commit -m "feat(watch): set-confirmation advances counters + enqueues outbox + sends

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 6.2: TDD outbox enqueue + transport `.setLog` send

**Files:** same as 6.1 (already partially done in 6.1's impl).

- [ ] **Step 1: Failing assertion appended to existing test**

Modify `test_currentExercise_andSetNum_advanceWithLogs` to also assert outbox + transport state:
```swift
let pending = try SetLogOutbox(directory: dir).pending()
XCTAssertEqual(pending.count, 0)  // each confirm should be acked-and-cleared in this test path? No — outbox holds until ack. Adjust expectation:

// Actually: outbox NEVER drains until an .ack arrives. So after 3 confirmations,
// 3 entries should be in the outbox.
let pendingFinal = try SetLogOutbox(directory: dir).pending()
XCTAssertEqual(pendingFinal.count, 3)
let sent = await transport.sent
let setLogSends = sent.filter { if case .setLog = $0.message { return true } else { return false } }
XCTAssertEqual(setLogSends.count, 3)
XCTAssertTrue(setLogSends.allSatisfy { $0.channel == .reliable })
```

- [ ] **Step 2: Run — verify PASS** (impl from 6.1 already covers it)

- [ ] **Step 3: Commit (test-only)**

```bash
git add ios/Packages/Features/WatchWorkout
git commit -m "test(watch): assert outbox + transport for set confirmations

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 6.3: TDD `endSession()` writes ended lifecycle and tells factory

**Files:** same store + tests

- [ ] **Step 1: Failing test**

```swift
func test_endSession_callsFactoryAndEmitsLifecycle() async throws {
    let transport = FakeTransport()
    let factory = FakeWorkoutSessionFactory()
    let dir = tempDir()
    let payload = WorkoutPayloadDTO(sessionID: UUID(), workoutID: UUID(),
        title: "T", activityKind: "k", exercises: [])
    let store = WatchSessionStore(transport: transport, outbox: SetLogOutbox(directory: dir),
        sessionFactory: factory,
        payloadStorage: PayloadFileStorage(directory: dir))
    await store.receivePayload(payload)
    try await store.start()
    try await store.endSession()
    XCTAssertTrue(factory.ended)
    XCTAssertEqual(store.state, .ended)
    let lastSent = await transport.sent.last
    XCTAssertEqual(lastSent?.message, .sessionLifecycle(.ended))
}
```

- [ ] **Step 2: Run — verify FAIL**

- [ ] **Step 3: Implement**

Add to store:
```swift
public func endSession() async throws {
    do {
        try await factory.endSession()
    } catch {
        PulseLogger.session.error("HKWorkoutSession.end failed", error)
    }
    state = .ended
    try? payloadStorage.clear()
    try? await transport.send(.sessionLifecycle(.ended), via: .live)
}
```

- [ ] **Step 4: Run — verify PASS**

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/Features/WatchWorkout
git commit -m "feat(watch): endSession — clear payload, emit lifecycle, end HK session

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 6.4: Implement `LiveWorkoutSessionFactory` (real `HKWorkoutSession`)

Real-device verifiable. Keep the surface tight; protocol is the seam.

**Files:**
- Create: `ios/Packages/Features/WatchWorkout/Sources/WatchWorkout/LiveWorkoutSessionFactory.swift`

- [ ] **Step 1: Implement**

```swift
import Foundation
import Logging
#if canImport(HealthKit)
import HealthKit

public final class LiveWorkoutSessionFactory: WorkoutSessionFactory {
    private let store: HKHealthStore
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    public init(store: HKHealthStore = HKHealthStore()) { self.store = store }

    public func startSession(activityKind: String) async throws -> UUID {
        let cfg = HKWorkoutConfiguration()
        cfg.activityType = Self.activityType(for: activityKind)
        cfg.locationType = .indoor
        let s = try HKWorkoutSession(healthStore: store, configuration: cfg)
        let b = s.associatedWorkoutBuilder()
        b.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: cfg)
        try await s.startActivity(with: Date())
        try await b.beginCollection(withStart: Date())
        // Companion mirroring — Phone receives lifecycle + builder data.
        try? await s.startMirroringToCompanionDevice()
        self.session = s
        self.builder = b
        return s.uuid
    }

    public func endSession() async throws {
        guard let s = session, let b = builder else { return }
        s.end()
        try await b.endCollection(withEnd: Date())
        _ = try await b.finishWorkout()  // writes HKWorkout
        self.session = nil
        self.builder = nil
    }

    public func recoverIfActive() async -> UUID? {
        // iOS 17/watchOS 10+: HKHealthStore exposes a recovery API. The exact name
        // varies across SDK versions; resolve at implementation time. This stub
        // returns nil until the device-side path is wired up in Task Group 13.
        return nil
    }

    private static func activityType(for kind: String) -> HKWorkoutActivityType {
        switch kind {
        case "traditionalStrengthTraining": return .traditionalStrengthTraining
        case "functionalStrengthTraining":  return .functionalStrengthTraining
        case "coreTraining":                return .coreTraining
        case "flexibility":                 return .flexibility
        case "mixedCardio":                 return .mixedCardio
        default:                            return .traditionalStrengthTraining
        }
    }
}
#endif
```

- [ ] **Step 2: Build**

Run: `cd ios/Packages/Features/WatchWorkout && swift build`
Expected: builds (HK guarded by `#if canImport(HealthKit)`).

- [ ] **Step 3: Commit**

```bash
git add ios/Packages/Features/WatchWorkout
git commit -m "feat(watch): LiveWorkoutSessionFactory — HKWorkoutSession + mirroring

Real HK plumbing; recovery API stubbed pending Task Group 13. Tests
continue using FakeWorkoutSessionFactory.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 6.5: Build `ActiveSetView`

**Files:**
- Create: `ios/Packages/Features/WatchWorkout/Sources/WatchWorkout/ActiveSetView.swift`

- [ ] **Step 1: View**

```swift
import SwiftUI
import WatchBridge

public struct ActiveSetView: View {
    public let exerciseName: String
    public let setNum: Int
    public let totalSets: Int
    public let prescribedReps: Int
    public let prescribedLoad: String
    public let onConfirm: () -> Void

    public init(exerciseName: String, setNum: Int, totalSets: Int,
                prescribedReps: Int, prescribedLoad: String,
                onConfirm: @escaping () -> Void) {
        self.exerciseName = exerciseName; self.setNum = setNum
        self.totalSets = totalSets; self.prescribedReps = prescribedReps
        self.prescribedLoad = prescribedLoad; self.onConfirm = onConfirm
    }

    public var body: some View {
        VStack(spacing: 6) {
            Text(exerciseName).font(.headline).lineLimit(1)
            Text("Set \(setNum) / \(totalSets)").font(.caption).foregroundStyle(.secondary)
            Text("\(prescribedReps) × \(prescribedLoad)").font(.title3).bold()
            Spacer(minLength: 4)
            Button("Set done", action: onConfirm).buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 8)
    }
}
```

- [ ] **Step 2: Smoke render**

Append to `WatchWorkoutTests/SmokeTests.swift`:
```swift
func test_activeSetView_renders() {
    let v = ActiveSetView(exerciseName: "Row", setNum: 1, totalSets: 3,
                          prescribedReps: 8, prescribedLoad: "100",
                          onConfirm: {})
    _ = v.body
}
```

- [ ] **Step 3: Run + commit**

```bash
git add ios/Packages/Features/WatchWorkout
git commit -m "feat(watch): ActiveSetView — exercise + prescription + Set-done CTA

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

# Task Group 7 — Rest screen + advance

### Task 7.1: TDD `advanceFromRest()`

**Files:** store + tests

- [ ] **Step 1: Failing test**

```swift
func test_advanceFromRest_returnsToActiveOrEnds() async throws {
    let payload = WorkoutPayloadDTO(sessionID: UUID(), workoutID: UUID(),
        title: "T", activityKind: "k",
        exercises: [.init(exerciseID: "row", name: "Row", sets: [
            .init(setNum: 1, prescribedReps: 8, prescribedLoad: "100"),
            .init(setNum: 2, prescribedReps: 8, prescribedLoad: "100")
        ])])
    let dir = tempDir()
    let store = WatchSessionStore(transport: FakeTransport(),
        outbox: SetLogOutbox(directory: dir),
        sessionFactory: FakeWorkoutSessionFactory(),
        payloadStorage: PayloadFileStorage(directory: dir))
    await store.receivePayload(payload)
    try await store.start()
    await store.confirmCurrentSet()  // → resting
    if case .resting = store.state {} else { XCTFail("expected .resting") }
    await store.advanceFromRest()
    XCTAssertEqual(store.state, .active)
    await store.confirmCurrentSet()  // last set → ended (no rest)
    XCTAssertEqual(store.state, .ended)
}
```

- [ ] **Step 2: Run — verify FAIL**

- [ ] **Step 3: Implement**

Add to store:
```swift
public func advanceFromRest() async {
    guard case .resting = state else { return }
    if currentExerciseID == nil {
        state = .ended
    } else {
        state = .active
    }
}
```

- [ ] **Step 4: Run — verify PASS**

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/Features/WatchWorkout
git commit -m "feat(watch): advanceFromRest — return to .active or transition .ended

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 7.2: Build `RestView`

**Files:**
- Create: `ios/Packages/Features/WatchWorkout/Sources/WatchWorkout/RestView.swift`

- [ ] **Step 1: View**

```swift
import SwiftUI

public struct RestView: View {
    public let secondsRemaining: Int
    public let onSkip: () -> Void
    public init(secondsRemaining: Int, onSkip: @escaping () -> Void) {
        self.secondsRemaining = secondsRemaining; self.onSkip = onSkip
    }
    public var body: some View {
        VStack(spacing: 8) {
            Text("Rest").font(.headline)
            Text("\(secondsRemaining)s").font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
            Button("Skip", action: onSkip).buttonStyle(.bordered).controlSize(.small)
        }
    }
}
```

- [ ] **Step 2: Smoke + commit**

Append to smoke tests:
```swift
func test_restView_renders() {
    _ = RestView(secondsRemaining: 60, onSkip: {}).body
}
```

```bash
git add ios/Packages/Features/WatchWorkout
git commit -m "feat(watch): RestView — countdown + skip

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 7.3: Build `WatchAppRoot` switching on state

**Files:**
- Create: `ios/Packages/Features/WatchWorkout/Sources/WatchWorkout/WatchAppRoot.swift`

- [ ] **Step 1: View**

```swift
import SwiftUI

public struct WatchAppRoot: View {
    @Bindable public var store: WatchSessionStore
    public init(store: WatchSessionStore) { self.store = store }

    public var body: some View {
        Group {
            switch store.state {
            case .idle, .ready:
                IdleView(payload: store.payload) {
                    Task { try? await store.start() }
                }
            case .starting:
                ProgressView("Starting…")
            case .active:
                if let exID = store.currentExerciseID,
                   let setNum = store.currentSetNum,
                   let payload = store.payload,
                   let ex = payload.exercises.first(where: { $0.exerciseID == exID }),
                   let pres = ex.sets.first(where: { $0.setNum == setNum })
                {
                    ActiveSetView(exerciseName: ex.name, setNum: setNum,
                                  totalSets: ex.sets.count,
                                  prescribedReps: pres.prescribedReps,
                                  prescribedLoad: pres.prescribedLoad) {
                        Task { await store.confirmCurrentSet() }
                    }
                } else {
                    Text("Workout complete").font(.headline)
                }
            case .resting:
                RestView(secondsRemaining: 60) {  // simple fixed for Plan 5
                    Task { await store.advanceFromRest() }
                }
            case .ended:
                Text("Done").font(.headline)
            case .failed(let reason):
                Text("Couldn't start (\(reason.rawValue))")
                    .multilineTextAlignment(.center).font(.caption)
            }
        }
    }
}
```

- [ ] **Step 2: Smoke + commit**

```swift
@MainActor func test_watchAppRoot_renders() async {
    let store = WatchSessionStore(transport: FakeTransport(),
        outbox: SetLogOutbox(directory: FileManager.default.temporaryDirectory),
        sessionFactory: FakeWorkoutSessionFactory(),
        payloadStorage: PayloadFileStorage(directory: FileManager.default.temporaryDirectory))
    _ = WatchAppRoot(store: store).body
}
```

```bash
git add ios/Packages/Features/WatchWorkout
git commit -m "feat(watch): WatchAppRoot — state-driven view switcher

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

# Task Group 8 — Wire Watch app target to `WatchSessionStore`

### Task 8.1: Replace `PulseWatchApp.swift` placeholder with real wiring

**Files:**
- Modify: `ios/PulseWatch/PulseWatchApp.swift`
- Create: `ios/PulseWatch/WatchAppContainer.swift`

- [ ] **Step 1: `WatchAppContainer.swift`**

```swift
import Foundation
import WatchBridge
import WatchWorkout
#if canImport(HealthKit)
import HealthKit
#endif

@MainActor
final class WatchAppContainer {
    let store: WatchSessionStore
    let transport: any WatchSessionTransport

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory,
                                                  in: .userDomainMask)[0]
        let outbox = SetLogOutbox(directory: appSupport)
        let payloadStorage = PayloadFileStorage(directory: appSupport)
        let live = LiveWatchSessionTransport()
        self.transport = live
        #if canImport(HealthKit)
        let factory: WorkoutSessionFactory = LiveWorkoutSessionFactory()
        #else
        let factory: WorkoutSessionFactory = FakeWorkoutSessionFactory()
        #endif
        self.store = WatchSessionStore(transport: live, outbox: outbox,
                                        sessionFactory: factory,
                                        payloadStorage: payloadStorage)

        // Bridge incoming payloads.
        Task { [store, transport] in
            for await msg in await transport.incoming {
                if case .workoutPayload(let p) = msg {
                    await store.receivePayload(p)
                }
            }
        }
    }
}
```

(Note: `FakeWorkoutSessionFactory` is currently in the test target. For the macOS build path the factory is unused — `#if canImport(HealthKit)` is true on watchOS. The fallback branch is a placeholder for compile cleanliness; Swift will still need it visible. Move the fake out of tests by promoting it to a `Sources/WatchWorkout/FakeWorkoutSessionFactory.swift` file marked `internal`, OR delete the `#else` branch and require HealthKit at build time. Pick the simpler option: require HealthKit, drop the `#else`.)

Adjust container to:
```swift
#if canImport(HealthKit)
let factory: WorkoutSessionFactory = LiveWorkoutSessionFactory()
self.store = WatchSessionStore(transport: live, outbox: outbox,
                                sessionFactory: factory,
                                payloadStorage: payloadStorage)
#else
fatalError("PulseWatch requires HealthKit")
#endif
```

- [ ] **Step 2: `PulseWatchApp.swift`**

```swift
import SwiftUI
import WatchWorkout

@main
struct PulseWatchApp: App {
    @State private var container = WatchAppContainer()
    var body: some Scene {
        WindowGroup {
            WatchAppRoot(store: container.store)
        }
    }
}
```

- [ ] **Step 3: Build**

Run: `cd ios && xcodegen generate && xcodebuild -workspace PulseApp.xcodeproj/project.xcworkspace -scheme PulseWatch -destination 'generic/platform=watchOS' -configuration Debug build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add ios/PulseWatch ios/PulseApp.xcodeproj
git commit -m "feat(watch): wire PulseWatch to WatchSessionStore + LiveWatchSessionTransport

Container forwards incoming workoutPayload messages to the store, which
drives the SwiftUI tree via WatchAppRoot.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

# Task Group 9 — Phone: accept set logs from Watch + start path with WCSession

### Task 9.1: TDD `SessionStore.applyRemoteSetLog(_:)` — idempotent via existing repo upsert

The existing Plan 4 store is `Features/InWorkout/Sources/InWorkout/SessionStore.swift`.

**Files:**
- Modify: `ios/Packages/Features/InWorkout/Sources/InWorkout/SessionStore.swift`
- Modify: `ios/Packages/Features/InWorkout/Tests/InWorkoutTests/SessionStoreTests.swift`
- Modify: `ios/Packages/Features/InWorkout/Package.swift` — add `WatchBridge` dep

- [ ] **Step 1: Add WatchBridge to InWorkout package**

In `Package.swift`:
- Add `.package(name: "WatchBridge", path: "../../WatchBridge")` to dependencies array.
- Add `.product(name: "WatchBridge", package: "WatchBridge")` to the `InWorkout` target deps.

- [ ] **Step 2: Failing test**

In `SessionStoreTests.swift`, add:
```swift
import WatchBridge

func test_applyRemoteSetLog_writesViaRepo() async throws {
    // assumes Plan 4 test scaffold provides a fresh in-memory model container + store
    let (store, ctx, sessionID, workoutID) = await makeStoreWithStartedSession()
    let dto = SetLogDTO(sessionID: sessionID, exerciseID: "row", setNum: 1,
                        reps: 8, load: "135", rpe: nil,
                        loggedAt: Date(timeIntervalSince1970: 0))
    await store.applyRemoteSetLog(dto)
    // existing fetch helper from Plan 4 tests
    let logs = try fetchSetLogs(ctx: ctx, sessionID: sessionID)
    XCTAssertEqual(logs.count, 1)
    XCTAssertEqual(logs[0].setNum, 1)
}

func test_applyRemoteSetLog_isIdempotentByNaturalKey() async throws {
    let (store, ctx, sessionID, _) = await makeStoreWithStartedSession()
    let dto = SetLogDTO(sessionID: sessionID, exerciseID: "row", setNum: 1,
                        reps: 8, load: "135", rpe: nil,
                        loggedAt: Date(timeIntervalSince1970: 0))
    await store.applyRemoteSetLog(dto)
    await store.applyRemoteSetLog(dto)
    let logs = try fetchSetLogs(ctx: ctx, sessionID: sessionID)
    XCTAssertEqual(logs.count, 1)
}
```

(`makeStoreWithStartedSession` and `fetchSetLogs` are scaffolding helpers from Plan 4 tests — reuse or create as parallels.)

- [ ] **Step 3: Run — verify FAIL**

- [ ] **Step 4: Implement**

In `SessionStore.swift`, add:
```swift
import WatchBridge

extension SessionStore {
    public func applyRemoteSetLog(_ dto: SetLogDTO) async {
        do {
            try sessionRepo.logSet(sessionID: dto.sessionID,
                                   exerciseID: dto.exerciseID,
                                   setNum: dto.setNum,
                                   reps: dto.reps,
                                   load: dto.load,
                                   rpe: dto.rpe ?? 0,
                                   now: dto.loggedAt)
        } catch {
            PulseLogger.session.error("applyRemoteSetLog failed", error)
        }
    }
}
```

(If `sessionRepo` is the existing private property name in Plan 4's store, use it. If different — search and adapt.)

- [ ] **Step 5: Run — verify PASS**

- [ ] **Step 6: Commit**

```bash
git add ios/Packages/Features/InWorkout
git commit -m "feat(in-workout): applyRemoteSetLog forwards to SessionRepository.logSet

Idempotency satisfied by existing repo upsert key (sessionID, exerciseID,
setNum). Two identical applies result in a single SetLogEntity row.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 9.2: TDD `SessionStore.bridgeIncoming(transport:)` task — drains incoming `.setLog` and `.sessionLifecycle`

**Files:** same as 9.1

- [ ] **Step 1: Failing test**

```swift
func test_bridgeIncoming_appliesSetLog() async throws {
    let (store, ctx, sessionID, _) = await makeStoreWithStartedSession()
    let transport = FakeTransport()
    let bridge = Task { await store.bridgeIncoming(transport: transport) }
    let dto = SetLogDTO(sessionID: sessionID, exerciseID: "row", setNum: 1,
        reps: 8, load: "135", rpe: nil, loggedAt: Date(timeIntervalSince1970: 0))
    await transport.simulateIncoming(.setLog(dto))
    try await Task.sleep(nanoseconds: 50_000_000)
    bridge.cancel()
    let logs = try fetchSetLogs(ctx: ctx, sessionID: sessionID)
    XCTAssertEqual(logs.count, 1)
}

func test_bridgeIncoming_recordsWatchSessionUUID() async throws {
    let (store, _, sessionID, _) = await makeStoreWithStartedSession()
    let transport = FakeTransport()
    let bridge = Task { await store.bridgeIncoming(transport: transport) }
    let watchUUID = UUID()
    await transport.simulateIncoming(.sessionLifecycle(.started(watchSessionUUID: watchUUID)))
    try await Task.sleep(nanoseconds: 50_000_000)
    bridge.cancel()
    XCTAssertEqual(store.watchSessionUUID, watchUUID)
}
```

- [ ] **Step 2: Run — verify FAIL**

- [ ] **Step 3: Implement**

```swift
extension SessionStore {
    /// Long-lived task: subscribes to transport.incoming and dispatches.
    public func bridgeIncoming(transport: any WatchSessionTransport) async {
        for await msg in await transport.incoming {
            switch msg {
            case .setLog(let dto):
                await applyRemoteSetLog(dto)
                try? await transport.send(.ack(naturalKey: dto.naturalKey), via: .live)
            case .sessionLifecycle(.started(let uuid)):
                self.watchSessionUUID = uuid
                // Persist to SessionEntity
                if let sid = activeSessionID {
                    try? sessionRepo.setWatchSessionUUID(sessionID: sid, watchSessionUUID: uuid)
                }
            case .sessionLifecycle(.ended):
                self.watchSessionEnded = true
            case .sessionLifecycle(.failed(let r)):
                PulseLogger.session.error("watch lifecycle failed: \(r.rawValue)")
                self.watchFailureReason = r
            case .ack, .workoutPayload:
                break
            }
        }
    }
}
```

(Add `watchSessionUUID`, `watchSessionEnded`, `watchFailureReason` `@Observable` properties to `SessionStore`. Add `SessionRepository.setWatchSessionUUID(sessionID:watchSessionUUID:)` if it doesn't exist — short helper using `ctx.atomicWrite`.)

- [ ] **Step 4: Add the missing repo helper**

In `SessionRepository.swift`, append:
```swift
public func setWatchSessionUUID(sessionID: UUID, watchSessionUUID: UUID) throws {
    let ctx = modelContainer.mainContext
    try ctx.atomicWrite {
        let sid = sessionID
        guard let session = try ctx.fetch(FetchDescriptor<SessionEntity>(
            predicate: #Predicate { $0.id == sid })).first else {
            throw SessionRepositoryError.sessionNotFound(sid)
        }
        session.watchSessionUUID = watchSessionUUID
    }
}
```

- [ ] **Step 5: Run — verify PASS**

- [ ] **Step 6: Commit**

```bash
git add ios/Packages/Features/InWorkout ios/Packages/Repositories
git commit -m "feat(in-workout): bridge transport.incoming → repo + SessionEntity

Set logs apply via SessionRepository.logSet (idempotent), lifecycle
.started records watchSessionUUID on the SessionEntity, and the store
publishes an Observation surface for the InWorkoutView to react to.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 9.3: TDD `SessionStore.start()` extension — push payload to Watch when reachable

**Files:** same store + tests

- [ ] **Step 1: Failing test**

```swift
func test_start_pushesPayloadWhenWatchReachable() async throws {
    let transport = FakeTransport()
    await transport.setReachable(true)
    let (store, _, _, workoutID) = await makeStoreWithFreshWorkout()
    try await store.startWithWatch(transport: transport)
    let sent = await transport.sent
    XCTAssertEqual(sent.count, 1)
    XCTAssertEqual(sent[0].channel, .reliable)
    if case .workoutPayload(let p) = sent[0].message {
        XCTAssertEqual(p.workoutID, workoutID)
    } else {
        XCTFail("expected payload push")
    }
}

func test_start_skipsPushWhenWatchUnreachable() async throws {
    let transport = FakeTransport()
    await transport.setReachable(false)
    let (store, _, _, _) = await makeStoreWithFreshWorkout()
    try await store.startWithWatch(transport: transport)
    let sent = await transport.sent
    XCTAssertTrue(sent.isEmpty)
}
```

- [ ] **Step 2: Run — verify FAIL**

- [ ] **Step 3: Implement**

```swift
extension SessionStore {
    /// Plan 5 entrypoint: starts the session locally, and if Watch is
    /// reachable, pushes the workout payload via reliable transport.
    public func startWithWatch(transport: any WatchSessionTransport) async throws {
        try await self.start()  // Plan 4's existing start path
        guard await transport.isReachable else { return }
        guard let payload = currentPayload() else { return }
        try await transport.send(.workoutPayload(payload), via: .reliable)
    }

    private func currentPayload() -> WorkoutPayloadDTO? {
        // Build from the in-flight workout + session + exercises.
        // Use the existing Plan 4 fetched workout — adapt to your store's
        // member name (e.g., self.workout, self.currentWorkout).
        guard let w = currentWorkout, let sid = activeSessionID else { return nil }
        let exercises: [WorkoutPayloadDTO.Exercise] = w.exercises.map { ex in
            .init(exerciseID: ex.exerciseID, name: ex.name,
                  sets: (1...ex.setCount).map { n in
                      .init(setNum: n, prescribedReps: ex.prescribedReps,
                            prescribedLoad: ex.prescribedLoad)
                  })
        }
        return WorkoutPayloadDTO(sessionID: sid, workoutID: w.id, title: w.title,
                                 activityKind: w.activityKind ?? "traditionalStrengthTraining",
                                 exercises: exercises)
    }
}
```

(Member names will need adaptation to Plan 4's actual `SessionStore` types — adjust as needed during implementation.)

- [ ] **Step 4: Run — verify PASS**

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/Features/InWorkout
git commit -m "feat(in-workout): startWithWatch pushes payload when reachable

When WCSession.isReachable is true, transferUserInfo a WorkoutPayloadDTO
to the Watch on workout start. Falls through to Plan 4's no-Watch path
when unreachable.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

# Task Group 10 — Phone: Live HR card via mirrored builder

### Task 10.1: TDD `MirroredSessionObserver` protocol + `FakeObserver`

**Files:**
- Create: `ios/Packages/WatchBridge/Sources/WatchBridge/MirroredSessionObserver.swift`
- Create: `ios/Packages/WatchBridge/Sources/WatchBridge/FakeMirroredObserver.swift`
- Create: `ios/Packages/WatchBridge/Tests/WatchBridgeTests/FakeMirroredObserverTests.swift`

- [ ] **Step 1: Failing test**

```swift
import XCTest
@testable import WatchBridge

final class FakeMirroredObserverTests: XCTestCase {
    func test_publishesHRSamples() async {
        let obs = FakeMirroredObserver()
        var received: [Int] = []
        let task = Task {
            for await bpm in await obs.heartRateBPM {
                received.append(bpm)
                if received.count >= 3 { break }
            }
        }
        await obs.simulateBPM(72)
        await obs.simulateBPM(74)
        await obs.simulateBPM(76)
        _ = await task.value
        XCTAssertEqual(received, [72, 74, 76])
    }
}
```

- [ ] **Step 2: Run — verify FAIL**

- [ ] **Step 3: Implement protocol + fake**

`MirroredSessionObserver.swift`:
```swift
import Foundation

public protocol MirroredSessionObserver: Actor {
    var heartRateBPM: AsyncStream<Int> { get }
    func startObserving() async
    func stopObserving() async
}
```

`FakeMirroredObserver.swift`:
```swift
import Foundation

public actor FakeMirroredObserver: MirroredSessionObserver {
    private var continuations: [AsyncStream<Int>.Continuation] = []
    public var heartRateBPM: AsyncStream<Int> {
        AsyncStream { cont in continuations.append(cont) }
    }
    public init() {}
    public func startObserving() async {}
    public func stopObserving() async {
        for c in continuations { c.finish() }
        continuations = []
    }
    public func simulateBPM(_ value: Int) {
        for c in continuations { c.yield(value) }
    }
}
```

- [ ] **Step 4: Run — verify PASS**

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/WatchBridge
git commit -m "feat(bridge): MirroredSessionObserver protocol + FakeMirroredObserver

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 10.2: TDD `LiveHRCardModel` — smoothing + staleness fallback

Pure logic — render-side decoupled.

**Files:**
- Create: `ios/Packages/Features/InWorkout/Sources/InWorkout/Components/LiveHRCardModel.swift`
- Create: `ios/Packages/Features/InWorkout/Tests/InWorkoutTests/LiveHRCardModelTests.swift`

- [ ] **Step 1: Failing test**

```swift
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
        // simple mean over recent 5s window: (70+80+90)/3 = 80
        XCTAssertEqual(m.displayBPM, 80)
    }
    func test_displayBPM_goesNilAfter10sStale() {
        var t = Date(timeIntervalSince1970: 100)
        let m = LiveHRCardModel(now: { t })
        m.record(bpm: 80, at: t)
        XCTAssertEqual(m.displayBPM, 80)
        t = Date(timeIntervalSince1970: 111)  // 11s elapsed
        XCTAssertNil(m.displayBPM)
    }
}
```

- [ ] **Step 2: Run — verify FAIL**

- [ ] **Step 3: Implement**

```swift
import Foundation
import Observation

@MainActor
@Observable
public final class LiveHRCardModel {
    private struct Sample { let bpm: Int; let at: Date }
    private var samples: [Sample] = []
    private let now: @Sendable () -> Date

    public init(now: @Sendable @escaping () -> Date = { Date() }) { self.now = now }

    public func record(bpm: Int, at: Date) {
        samples.append(.init(bpm: bpm, at: at))
        // Keep only last 5s of samples for smoothing
        let cutoff = at.addingTimeInterval(-5)
        samples.removeAll { $0.at < cutoff }
    }

    public var displayBPM: Int? {
        guard let latest = samples.last else { return nil }
        if now().timeIntervalSince(latest.at) > 10 { return nil }
        let recent = samples.filter { now().timeIntervalSince($0.at) <= 5 }
        guard !recent.isEmpty else { return nil }
        let mean = Double(recent.reduce(0) { $0 + $1.bpm }) / Double(recent.count)
        return Int(mean.rounded())
    }
}
```

- [ ] **Step 4: Run — verify PASS**

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/Features/InWorkout
git commit -m "feat(in-workout): LiveHRCardModel — 5s smoothing + 10s staleness

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 10.3: Build `LiveHRCardView` and place it in `InWorkoutView`

**Files:**
- Create: `ios/Packages/Features/InWorkout/Sources/InWorkout/Components/LiveHRCardView.swift`
- Modify: `ios/Packages/Features/InWorkout/Sources/InWorkout/InWorkoutView.swift` — insert at top
- Modify smoke test

- [ ] **Step 1: View**

```swift
import SwiftUI
import DesignSystem

public struct LiveHRCardView: View {
    @Bindable public var model: LiveHRCardModel
    public init(model: LiveHRCardModel) { self.model = model }
    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "heart.fill").foregroundStyle(.red)
            if let bpm = model.displayBPM {
                Text("\(bpm)").font(.system(.title3, design: .rounded)).bold()
                    .monospacedDigit()
                Text("bpm").font(.caption).foregroundStyle(.secondary)
            } else {
                Text("—").font(.system(.title3, design: .rounded)).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
```

- [ ] **Step 2: Wire into `InWorkoutView`**

Find the existing top of the InWorkoutView body. Insert above the existing `LiveMetricsGridView` (or wherever Plan 4's metrics begin):
```swift
LiveHRCardView(model: store.hrCardModel)
    .padding(.horizontal, 16)
```

Add `let hrCardModel: LiveHRCardModel` (or `@Observable` member) to `SessionStore`. Wire the observer task in `bridgeIncoming` or alongside it:
```swift
public func bridgeMirroredObserver(_ observer: any MirroredSessionObserver) async {
    await observer.startObserving()
    for await bpm in await observer.heartRateBPM {
        await MainActor.run {
            self.hrCardModel.record(bpm: bpm, at: Date())
        }
    }
}
```

- [ ] **Step 3: Smoke render check**

Add to `InWorkoutTests/SmokeTests.swift`:
```swift
@MainActor func test_liveHRCardView_renders() {
    _ = LiveHRCardView(model: LiveHRCardModel()).body
}
```

- [ ] **Step 4: Run + commit**

```bash
git add ios/Packages/Features/InWorkout
git commit -m "feat(in-workout): LiveHRCardView at top of InWorkoutView

Subscribes via MirroredSessionObserver; '—' until first BPM, smoothed
over 5s, returns to '—' after 10s without new samples.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 10.4: Implement `LiveMirroredSessionObserver` (real `HKHealthStore` mirroring)

Real-device verifiable. The exact API names for the mirroring start handler and HR-quantity-type vary between iOS 17 and iOS 18. Pick what works on the user's device target (latest), and document in the file.

**Files:**
- Create: `ios/Packages/WatchBridge/Sources/WatchBridge/LiveMirroredSessionObserver.swift`

- [ ] **Step 1: Implement**

```swift
import Foundation
import Logging
#if canImport(HealthKit)
import HealthKit

public actor LiveMirroredSessionObserver: MirroredSessionObserver {
    private let store: HKHealthStore
    private var continuations: [AsyncStream<Int>.Continuation] = []
    private var observingTask: Task<Void, Never>?

    public var heartRateBPM: AsyncStream<Int> {
        AsyncStream { cont in continuations.append(cont) }
    }

    public init(store: HKHealthStore = HKHealthStore()) { self.store = store }

    public func startObserving() async {
        // Phone-side: register the workoutSessionMirroringStartHandler.
        // The closure fires when a Watch session begins mirroring to this device.
        // Once mirrored, attach to the session's builder and observe HR samples.
        store.workoutSessionMirroringStartHandler = { [weak self] mirrored in
            Task { [weak self] in await self?.attach(to: mirrored) }
        }
    }

    private func attach(to session: HKWorkoutSession) async {
        let builder = session.associatedWorkoutBuilder()
        // Subscribe to HR samples via the builder's data delegate.
        // Plan 5 uses a data-handler protocol; the exact API name (data publisher
        // vs delegate) is resolved at implementation time against the device SDK.
        builder.delegate = HRBuilderDelegate { [weak self] bpm in
            Task { [weak self] in await self?.publish(bpm) }
        }
    }

    private func publish(_ bpm: Int) {
        for c in continuations { c.yield(bpm) }
    }

    public func stopObserving() async {
        store.workoutSessionMirroringStartHandler = nil
        for c in continuations { c.finish() }
        continuations = []
    }
}

// Bridge HKLiveWorkoutBuilderDelegate → callback closure.
private final class HRBuilderDelegate: NSObject, HKLiveWorkoutBuilderDelegate {
    let onBPM: (Int) -> Void
    init(onBPM: @escaping (Int) -> Void) { self.onBPM = onBPM }

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                        didCollectDataOf collectedTypes: Set<HKSampleType>) {
        guard collectedTypes.contains(HKQuantityType(.heartRate)) else { return }
        let stats = workoutBuilder.statistics(for: HKQuantityType(.heartRate))
        if let q = stats?.mostRecentQuantity() {
            let bpm = Int(q.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
            onBPM(bpm)
        }
    }
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
#endif
```

- [ ] **Step 2: Build (no unit tests — fake covers the protocol contract)**

Run: `cd ios/Packages/WatchBridge && swift build`

- [ ] **Step 3: Commit**

```bash
git add ios/Packages/WatchBridge
git commit -m "feat(bridge): LiveMirroredSessionObserver — Phone-side mirroring + HR

Verified via real-device smoke. Observes the mirrored HKWorkoutSession's
HKLiveWorkoutBuilder for HR samples and publishes Int BPM via AsyncStream.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

# Task Group 11 — Phone: HK write auth JIT + WCSession activation

### Task 11.1: TDD JIT auth flow in `SessionStore.startWithWatch`

**Files:** modify `SessionStore.swift` + tests

- [ ] **Step 1: Failing test**

```swift
func test_startWithWatch_requestsWriteAuthIfUndetermined() async throws {
    let transport = FakeTransport()
    await transport.setReachable(true)
    let (store, _, _, _) = await makeStoreWithFreshWorkoutAndFakeHK(authStatus: .undetermined)
    try await store.startWithWatch(transport: transport)
    let fakeHK = store.healthKit  // expose for testing
    XCTAssertTrue(fakeHK.didRequestWriteAuth)
}

func test_startWithWatch_skipsAuthIfAlreadyAuthorized() async throws {
    let transport = FakeTransport()
    await transport.setReachable(true)
    let (store, _, _, _) = await makeStoreWithFreshWorkoutAndFakeHK(authStatus: .authorized)
    try await store.startWithWatch(transport: transport)
    XCTAssertFalse(store.healthKit.didRequestWriteAuth)
}
```

- [ ] **Step 2: Run — verify FAIL**

- [ ] **Step 3: Implement**

In `SessionStore.swift`, modify `startWithWatch`:
```swift
public func startWithWatch(transport: any WatchSessionTransport) async throws {
    if healthKit.writeAuthorizationStatus() == .undetermined {
        try? await healthKit.requestWriteAuthorization()
    }
    try await self.start()
    // ... payload push as before
}
```

(Use whatever name the existing store uses for the `HealthKitClient` — `healthKit`, `hk`, etc.)

- [ ] **Step 4: Run — verify PASS**

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/Features/InWorkout
git commit -m "feat(in-workout): JIT HealthKit write-auth on workout start

When write-auth status is .undetermined, request it before pushing
payload to Watch. Denial is silent — workout still saves to SwiftData;
HKWorkout write is best-effort.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 11.2: Activate `WCSession` + `LiveMirroredSessionObserver` in `PulseApp`

**Files:**
- Modify: `ios/PulseApp/PulseApp.swift`
- Modify: `ios/PulseApp/AppShellRoot.swift` (where `SessionStore` is wired into `InWorkoutView`)
- Modify: `ios/PulseApp/Info.plist` — confirm HealthKit description strings exist

- [ ] **Step 1: Activate `WCSession` at app launch**

In `PulseApp.swift`, in the `App` struct's init, instantiate a singleton `LiveWatchSessionTransport` and store on the AppContainer (or wherever the existing infra lives). Do not block UI on activation.

- [ ] **Step 2: Wire `bridgeIncoming` + `bridgeMirroredObserver` to `SessionStore` lifecycle**

Where `InWorkoutView` is presented, kick off two long-lived tasks:
```swift
.task {
    await store.bridgeIncoming(transport: container.transport)
}
.task {
    await store.bridgeMirroredObserver(container.observer)
}
```

- [ ] **Step 3: Confirm Info.plist strings**

`ios/PulseApp/Info.plist` — ensure `NSHealthUpdateUsageDescription` exists; if not, add (matching watch-side copy):
```
"Pulse saves completed workouts to Health so the AI can adapt your plan over time."
```

- [ ] **Step 4: Build**

Run: `cd ios && xcodegen generate && xcodebuild -workspace PulseApp.xcodeproj/project.xcworkspace -scheme PulseApp -destination 'generic/platform=iOS' -configuration Debug build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add ios/PulseApp ios/PulseApp.xcodeproj
git commit -m "feat(app-shell): activate WCSession + mirrored observer at launch

LiveWatchSessionTransport activates WCSession on init; SessionStore
attaches to incoming messages + the mirrored HR stream when InWorkoutView
appears.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

# Task Group 12 — Watch: HK auth on first launch + Phone-side denial banner

### Task 12.1: TDD Watch HK auth check in `WatchSessionStore.start()`

**Files:** modify store + tests

- [ ] **Step 1: Add a `HealthKitAuthGate` protocol the store consults**

`ios/Packages/Features/WatchWorkout/Sources/WatchWorkout/HealthKitAuthGate.swift`:
```swift
public protocol HealthKitAuthGate: Sendable {
    func currentStatus() async -> WriteAuthStatus
    func request() async -> WriteAuthStatus
}
```

(Reuse `WriteAuthStatus` from `HealthKitClient`; add `import HealthKitClient` to the package deps.)

- [ ] **Step 2: Failing test**

```swift
func test_start_requestsAuthIfUndetermined_andContinuesOnGrant() async throws {
    let transport = FakeTransport()
    let factory = FakeWorkoutSessionFactory()
    let dir = tempDir()
    let payload = WorkoutPayloadDTO(sessionID: UUID(), workoutID: UUID(),
        title: "T", activityKind: "k", exercises: [])
    let gate = StubAuthGate(initial: .undetermined, afterRequest: .authorized)
    let store = WatchSessionStore(transport: transport,
        outbox: SetLogOutbox(directory: dir),
        sessionFactory: factory,
        payloadStorage: PayloadFileStorage(directory: dir),
        authGate: gate)
    await store.receivePayload(payload)
    try await store.start()
    XCTAssertEqual(gate.requestCount, 1)
    XCTAssertEqual(store.state, .active)
}

func test_start_emitsHealthKitDenied_onDenial() async throws {
    let transport = FakeTransport()
    let factory = FakeWorkoutSessionFactory()
    let dir = tempDir()
    let payload = WorkoutPayloadDTO(sessionID: UUID(), workoutID: UUID(),
        title: "T", activityKind: "k", exercises: [])
    let gate = StubAuthGate(initial: .undetermined, afterRequest: .denied)
    let store = WatchSessionStore(transport: transport,
        outbox: SetLogOutbox(directory: dir),
        sessionFactory: factory,
        payloadStorage: PayloadFileStorage(directory: dir),
        authGate: gate)
    await store.receivePayload(payload)
    do {
        try await store.start()
        XCTFail("expected throw")
    } catch {}
    XCTAssertEqual(store.state, .failed(reason: .healthKitDenied))
    let sent = await transport.sent
    XCTAssertTrue(sent.contains(where: { $0.message == .sessionLifecycle(.failed(reason: .healthKitDenied)) }))
}

final class StubAuthGate: HealthKitAuthGate {
    var current: WriteAuthStatus
    var afterRequest: WriteAuthStatus
    var requestCount = 0
    init(initial: WriteAuthStatus, afterRequest: WriteAuthStatus) {
        self.current = initial; self.afterRequest = afterRequest
    }
    func currentStatus() async -> WriteAuthStatus { current }
    func request() async -> WriteAuthStatus {
        requestCount += 1; current = afterRequest; return afterRequest
    }
}
```

- [ ] **Step 3: Run — verify FAIL**

- [ ] **Step 4: Implement**

Modify `WatchSessionStore.init` to take `authGate: HealthKitAuthGate`. Modify `start()`:
```swift
public func start() async throws {
    guard let payload else { return }
    var status = await authGate.currentStatus()
    if status == .undetermined { status = await authGate.request() }
    if status == .denied {
        state = .failed(reason: .healthKitDenied)
        try? await transport.send(.sessionLifecycle(.failed(reason: .healthKitDenied)),
                                  via: .live)
        throw NSError(domain: "WatchSessionStore", code: 1)
    }
    state = .starting
    do {
        let uuid = try await factory.startSession(activityKind: payload.activityKind)
        watchSessionUUID = uuid
        state = .active
        try await transport.send(.sessionLifecycle(.started(watchSessionUUID: uuid)),
                                 via: .live)
    } catch {
        state = .failed(reason: .sessionStartFailed)
        try? await transport.send(.sessionLifecycle(.failed(reason: .sessionStartFailed)),
                                  via: .live)
        throw error
    }
}
```

Add a default param: `authGate: HealthKitAuthGate = AlwaysAuthorizedGate()` for tests that don't care, and a `LiveAuthGate` wrapping `HealthKitClient.requestWriteAuthorization()` for the live container.

- [ ] **Step 5: Run — verify PASS**

- [ ] **Step 6: Commit**

```bash
git add ios/Packages/Features/WatchWorkout
git commit -m "feat(watch): JIT HealthKit auth in WatchSessionStore.start

Undetermined → request → continue on grant; deny → emit .healthKitDenied
lifecycle and transition to .failed.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 12.2: TDD Phone-side Home banner on `.healthKitDenied`

**Files:**
- Modify: `ios/Packages/Features/Home/Sources/Home/HomeStore.swift`
- Modify: `ios/Packages/Features/Home/Sources/Home/HomeView.swift`
- Tests: `ios/Packages/Features/Home/Tests/HomeTests/HomeStoreTests.swift`

- [ ] **Step 1: Failing test**

```swift
func test_setWatchAuthDenied_setsBannerVisible() async {
    let store = HomeStore(...)
    XCTAssertFalse(store.watchHKDeniedBannerVisible)
    store.setWatchHKDenied()
    XCTAssertTrue(store.watchHKDeniedBannerVisible)
}

func test_dismissWatchAuthBanner_clears() async {
    let store = HomeStore(...)
    store.setWatchHKDenied()
    store.dismissWatchHKBanner()
    XCTAssertFalse(store.watchHKDeniedBannerVisible)
}
```

- [ ] **Step 2: Run — verify FAIL**

- [ ] **Step 3: Implement**

Add to `HomeStore`:
```swift
public var watchHKDeniedBannerVisible: Bool {
    get { UserDefaults.standard.bool(forKey: Self.bannerKey)
          && !UserDefaults.standard.bool(forKey: Self.dismissedKey) }
}
public func setWatchHKDenied() {
    UserDefaults.standard.set(true, forKey: Self.bannerKey)
}
public func dismissWatchHKBanner() {
    UserDefaults.standard.set(true, forKey: Self.dismissedKey)
}
private static let bannerKey = "pulse.watch.hkDenied"
private static let dismissedKey = "pulse.watch.hkDeniedDismissed"
```

Wire in `HomeView` body:
```swift
if store.watchHKDeniedBannerVisible {
    Banner(text: "Watch declined HealthKit access — open the Watch app to enable.",
           onDismiss: { store.dismissWatchHKBanner() })
}
```

(`Banner` SwiftUI primitive: a small thin-material card with text + "X" — match `DesignSystem` patterns.)

Wire `SessionStore.bridgeIncoming` to call `homeStore.setWatchHKDenied()` when the lifecycle case is `.failed(reason: .healthKitDenied)`. Pass `homeStore` reference into `SessionStore` if it isn't already.

- [ ] **Step 4: Run + commit**

```bash
git add ios/Packages/Features/Home ios/Packages/Features/InWorkout
git commit -m "feat(home): one-time banner when Watch denies HealthKit

UserDefaults-backed (visibility key + dismiss key); cleared via the
banner's X. Triggered from SessionStore on .sessionLifecycle(.failed(.healthKitDenied)).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

# Task Group 13 — Mid-session resume

### Task 13.1: TDD Watch-side recovery: `recoverIfActive()`

**Files:** `WatchSessionStore` + tests

- [ ] **Step 1: Failing test**

```swift
func test_recoverIfActive_restoresStateFromPayloadAndUUID() async throws {
    let dir = tempDir()
    let payload = WorkoutPayloadDTO(sessionID: UUID(), workoutID: UUID(),
        title: "T", activityKind: "k", exercises: [])
    let storage = PayloadFileStorage(directory: dir)
    try storage.write(payload)

    let factory = FakeWorkoutSessionFactory()
    factory.recoveredUUID = UUID()
    let store = WatchSessionStore(transport: FakeTransport(),
        outbox: SetLogOutbox(directory: dir),
        sessionFactory: factory,
        payloadStorage: storage,
        authGate: AlwaysAuthorizedGate())
    await store.recoverIfActive()
    XCTAssertEqual(store.state, .active)
    XCTAssertEqual(store.payload, payload)
    XCTAssertEqual(store.watchSessionUUID, factory.recoveredUUID)
}

func test_recoverIfActive_doesNothingWhenNoActiveSession() async throws {
    let dir = tempDir()
    let factory = FakeWorkoutSessionFactory()  // recoveredUUID = nil
    let store = WatchSessionStore(transport: FakeTransport(),
        outbox: SetLogOutbox(directory: dir),
        sessionFactory: factory,
        payloadStorage: PayloadFileStorage(directory: dir),
        authGate: AlwaysAuthorizedGate())
    await store.recoverIfActive()
    XCTAssertEqual(store.state, .idle)
}
```

- [ ] **Step 2: Run — verify FAIL**

- [ ] **Step 3: Implement**

Add to `WatchSessionStore`:
```swift
public func recoverIfActive() async {
    let recovered = await factory.recoverIfActive()
    let stored = try? payloadStorage.read()
    guard let uuid = recovered, let payload = stored else { return }
    self.payload = payload
    self.watchSessionUUID = uuid
    self.state = .active
}
```

- [ ] **Step 4: Implement real recovery in `LiveWorkoutSessionFactory`**

Replace the stub `recoverIfActive` with the appropriate device call. The exact API name varies — confirm against the SDK on the user's machine. Likely candidate:
```swift
public func recoverIfActive() async -> UUID? {
    // iOS 17/watchOS 10+: HKHealthStore.recoverActiveWorkoutSession
    // Resolve via Xcode autocomplete; signature returns the active session if any.
    return await withCheckedContinuation { cont in
        store.recoverActiveWorkoutSession { session, _ in
            cont.resume(returning: session?.uuid)
        }
    }
}
```

- [ ] **Step 5: Run — verify PASS**

- [ ] **Step 6: Commit**

```bash
git add ios/Packages/Features/WatchWorkout
git commit -m "feat(watch): mid-session recovery — recoverIfActive restores state

Reads persisted payload + queries HKHealthStore for an active workout
session; if both present, transitions to .active and reuses the existing
session UUID.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 13.2: Wire `recoverIfActive` into Watch app launch

**Files:**
- Modify: `ios/PulseWatch/WatchAppContainer.swift` (or `PulseWatchApp.swift`)

- [ ] **Step 1: Add launch task**

```swift
init() {
    // ... existing init
    Task { [store] in await store.recoverIfActive() }
}
```

- [ ] **Step 2: Build + commit**

```bash
git add ios/PulseWatch
git commit -m "feat(watch): trigger recoverIfActive at app launch

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 13.3: TDD Phone-side resume — `FirstRunGate` defers cleanup when active mirrored session exists

**Files:**
- Modify: `ios/Packages/AppShell/Sources/AppShell/FirstRunGate.swift`
- Tests: add `FirstRunGateResumeTests.swift` if absent

- [ ] **Step 1: Failing test**

```swift
import XCTest
@testable import AppShell

@MainActor
final class FirstRunGateResumeTests: XCTestCase {
    func test_orphanCleanup_runsWhenNoActiveMirroredSession() async {
        // Set up: create an in-progress SessionEntity in an in-memory container.
        // Pre-condition: HKMirroringStub returns `nil` (no active session).
        // Run FirstRunGate.checkFirstRun() (or extracted helper).
        // Expect: orphan session was discarded.
    }
    func test_orphanCleanup_skippedWhenActiveMirroredSession() async {
        // Same setup, but HKMirroringStub returns a non-nil UUID.
        // Expect: orphan session is preserved (not discarded).
    }
}
```

(Test-double notes: `HKMirroringStub` is a tiny protocol behind `recoverActiveWorkoutSession`. Inject it into `FirstRunGate`.)

- [ ] **Step 2: Refactor `FirstRunGate.checkFirstRun()` to take a probe**

Add a `MirroredSessionProbe` protocol:
```swift
public protocol MirroredSessionProbe: Sendable {
    func activeWatchSessionUUID() async -> UUID?
}
```

Default impl wraps `LiveWorkoutSessionFactory.recoverIfActive` (move that helper to be Phone-callable, OR add a Phone-side wrapper around `HKHealthStore.recoverActiveWorkoutSession`).

In `FirstRunGate.checkFirstRun()`, replace the orphan-cleanup block (line 103-107) with:
```swift
let sessionRepo = SessionRepository(modelContainer: appContainer.modelContainer)
if let orphan = try? sessionRepo.orphanedInProgressSession() {
    let activeUUID = await appContainer.mirroredProbe.activeWatchSessionUUID()
    if activeUUID == nil {
        try? sessionRepo.discardSession(id: orphan.id)
    }
    // else: leave it; the resume path in SessionStore will pick it up.
}
```

- [ ] **Step 3: Run — verify PASS**

- [ ] **Step 4: Commit**

```bash
git add ios/Packages/AppShell ios/PulseApp
git commit -m "feat(app-shell): defer orphan cleanup when Watch session is still active

Replaces Plan 4's unconditional cleanup with a probe of the device's
active HKWorkoutSession. If a mirrored session is alive the orphan
SessionEntity is preserved for the resume path.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 13.4: TDD Phone-side resume — present `InWorkoutView` when orphan + active session

**Files:**
- Modify: `ios/Packages/AppShell/Sources/AppShell/RootScaffold.swift` (or wherever the InWorkout flow is presented from Plan 4)

- [ ] **Step 1: Failing scenario**

The hook is wherever the existing app routes a fresh-launch user to Home vs. to a mid-session view. Add a third route: if `orphanedInProgressSession() != nil && activeWatchSessionUUID() != nil`, present `InWorkoutView` for that orphan session directly.

- [ ] **Step 2: Implement**

Pseudocode in `RootScaffold`:
```swift
.task {
    let orphan = try? sessionRepo.orphanedInProgressSession()
    let active = await mirroredProbe.activeWatchSessionUUID()
    if let orphan, active != nil {
        resumePending = orphan
    }
}
.fullScreenCover(item: $resumePending) { session in
    InWorkoutView(/* resume context */)
}
```

- [ ] **Step 3: Build + commit**

```bash
git add ios/Packages/AppShell ios/PulseApp
git commit -m "feat(app-shell): resume InWorkoutView when active mirrored session exists

On launch, if an orphan SessionEntity AND an active HKWorkoutSession both
exist, present InWorkoutView for the orphan instead of running cleanup.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

# Task Group 14 — Outbox replay + ack handling

### Task 14.1: TDD outbox replay-on-reachability

**Files:** `WatchSessionStore` + tests

- [ ] **Step 1: Failing test**

```swift
func test_outboxReplays_onReachabilityGain() async throws {
    let transport = FakeTransport()
    await transport.setReachable(false)
    let dir = tempDir()
    let outbox = SetLogOutbox(directory: dir)
    // Pre-populate outbox with two pending logs (simulating prior unreachability).
    let s = UUID()
    let a = SetLogDTO(sessionID: s, exerciseID: "e", setNum: 1, reps: 5, load: "0", rpe: nil, loggedAt: Date())
    let b = SetLogDTO(sessionID: s, exerciseID: "e", setNum: 2, reps: 5, load: "0", rpe: nil, loggedAt: Date())
    try outbox.enqueue(a); try outbox.enqueue(b)
    let store = WatchSessionStore(transport: transport, outbox: outbox,
        sessionFactory: FakeWorkoutSessionFactory(),
        payloadStorage: PayloadFileStorage(directory: dir),
        authGate: AlwaysAuthorizedGate())
    await transport.setReachable(true)
    await store.replayOutbox()
    let sent = await transport.sent
    let setLogs = sent.filter { if case .setLog = $0.message { return true } else { return false } }
    XCTAssertEqual(setLogs.count, 2)
}
```

- [ ] **Step 2: Run — verify FAIL**

- [ ] **Step 3: Implement**

```swift
public func replayOutbox() async {
    guard await transport.isReachable else { return }
    let pending = (try? outbox.pending()) ?? []
    for log in pending {
        try? await transport.send(.setLog(log), via: .reliable)
    }
}
```

- [ ] **Step 4: Run — verify PASS**

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/Features/WatchWorkout
git commit -m "feat(watch): replayOutbox sends pending set logs over reliable channel

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 14.2: TDD ack-driven outbox drain

**Files:** Watch container subscribes to incoming `.ack` and drains.

- [ ] **Step 1: Failing test**

```swift
func test_ackDrainsOutbox() async throws {
    let transport = FakeTransport()
    let dir = tempDir()
    let outbox = SetLogOutbox(directory: dir)
    let log = SetLogDTO(sessionID: UUID(), exerciseID: "e", setNum: 1,
        reps: 5, load: "0", rpe: nil, loggedAt: Date())
    try outbox.enqueue(log)
    let store = WatchSessionStore(transport: transport, outbox: outbox,
        sessionFactory: FakeWorkoutSessionFactory(),
        payloadStorage: PayloadFileStorage(directory: dir),
        authGate: AlwaysAuthorizedGate())
    let bridge = Task { await store.bridgeIncomingAcks() }
    await transport.simulateIncoming(.ack(naturalKey: log.naturalKey))
    try await Task.sleep(nanoseconds: 50_000_000)
    bridge.cancel()
    XCTAssertEqual(try outbox.pending().count, 0)
}
```

- [ ] **Step 2: Run — verify FAIL**

- [ ] **Step 3: Implement**

```swift
public func bridgeIncomingAcks() async {
    for await msg in await transport.incoming {
        if case .ack(let key) = msg {
            try? outbox.drain(naturalKey: key)
        }
    }
}
```

Wire this in `WatchAppContainer.init` alongside payload subscription.

- [ ] **Step 4: Run + commit**

```bash
git add ios/Packages/Features/WatchWorkout ios/PulseWatch
git commit -m "feat(watch): drain outbox entry on Phone .ack

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

# Task Group 15 — Capabilities, entitlements, project polish

### Task 15.1: HealthKit + WatchConnectivity entitlements on `PulseApp`

**Files:**
- Modify: `ios/PulseApp/PulseApp.entitlements`

- [ ] **Step 1: Confirm/add entitlements**

`PulseApp.entitlements` should include:
```xml
<key>com.apple.developer.healthkit</key>
<true/>
<key>com.apple.developer.healthkit.access</key>
<array/>
```

`WCSession` doesn't require an entitlement; just being a paired-companion target enables it.

- [ ] **Step 2: PulseWatch entitlements file**

Create `ios/PulseWatch/PulseWatch.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.healthkit</key>
    <true/>
    <key>com.apple.developer.healthkit.access</key>
    <array/>
</dict>
</plist>
```

Wire it in `Project.yml` under the `PulseWatch` target's settings:
```yaml
        CODE_SIGN_ENTITLEMENTS: PulseWatch/PulseWatch.entitlements
```

- [ ] **Step 3: Regenerate + build both targets**

```bash
cd ios && xcodegen generate && \
  xcodebuild -workspace PulseApp.xcodeproj/project.xcworkspace -scheme PulseApp -destination 'generic/platform=iOS' build && \
  xcodebuild -workspace PulseApp.xcodeproj/project.xcworkspace -scheme PulseWatch -destination 'generic/platform=watchOS' build
```

- [ ] **Step 4: Commit**

```bash
git add ios/PulseApp ios/PulseWatch ios/Project.yml ios/PulseApp.xcodeproj
git commit -m "chore(capabilities): HealthKit entitlements on both targets

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

# Task Group 16 — Integration tests on Phone target

### Task 16.1: TDD `PulseAppIntegrationTests` — start → set logs → end

**Files:**
- Create: `ios/Tests/PulseAppIntegrationTests/EndToEndTests.swift` (new XCTest target)
- Modify: `ios/Project.yml` — add the test target

- [ ] **Step 1: Add test target to `Project.yml`**

Under `targets:`:
```yaml
  PulseAppIntegrationTests:
    type: bundle.unit-test
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - path: Tests/PulseAppIntegrationTests
    settings:
      base:
        INFOPLIST_FILE: Tests/PulseAppIntegrationTests/Info.plist
    dependencies:
      - target: PulseApp
      - package: WatchBridge
      - package: InWorkout
      - package: Repositories
      - package: Persistence
```

- [ ] **Step 2: Write end-to-end test**

`EndToEndTests.swift`:
```swift
import XCTest
import WatchBridge
import InWorkout
import Repositories
import Persistence
import SwiftData

@MainActor
final class EndToEndTests: XCTestCase {
    func test_startWorkout_pushesPayload_appliesSetLogs_finishes() async throws {
        let container = try ModelContainer(for: PulseModelContainer.allTypes(),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        // Seed a Workout + Plan; call PlanRepository.streamFirstPlan or insert directly.
        // (Use the Plan 4 test scaffolding helpers for this.)

        let transport = FakeTransport()
        await transport.setReachable(true)

        let store = SessionStore(modelContainer: container,
                                  // ... pass in real or fake HK client / observer
                                 )
        try await store.startWithWatch(transport: transport)
        // Expect: one .workoutPayload sent over .reliable.
        let sent1 = await transport.sent
        XCTAssertEqual(sent1.count, 1)

        let sid = store.activeSessionID!
        let log = SetLogDTO(sessionID: sid, exerciseID: "row", setNum: 1,
                            reps: 8, load: "135", rpe: nil, loggedAt: Date())
        await transport.simulateIncoming(.setLog(log))
        // Wait for bridgeIncoming to apply.
        try await Task.sleep(nanoseconds: 100_000_000)

        // Assert SetLogEntity row exists.
        let ctx = container.mainContext
        let logs = try ctx.fetch(FetchDescriptor<SetLogEntity>())
        XCTAssertEqual(logs.count, 1)

        // Watch sends ended.
        await transport.simulateIncoming(.sessionLifecycle(.ended))
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(store.watchSessionEnded)
    }
}
```

- [ ] **Step 3: Run**

Run: `cd ios && xcodebuild test -workspace PulseApp.xcodeproj/project.xcworkspace -scheme PulseAppIntegrationTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -resultBundlePath /tmp/plan5-integration.xcresult`
Expected: test passes.

- [ ] **Step 4: Commit**

```bash
git add ios/Tests ios/Project.yml ios/PulseApp.xcodeproj
git commit -m "test(integration): end-to-end Phone session loop with FakeTransport

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

# Task Group 17 — Real-device smoke (the ship gate)

### Task 17.1: Author the smoke checklist

**Files:**
- Create: `docs/superpowers/smoke/plan-5-watch-smoke.md`

- [ ] **Step 1: Write checklist**

```markdown
# Plan 5 Watch Smoke Checklist

Run on **iPhone 17 Pro + Apple Watch Series 11** (latest iOS/watchOS).
All seven scenarios must pass before pushing to `origin/main`.

## Pre-flight
- [ ] Both apps installed on real devices (not simulator)
- [ ] Phone HealthKit auth not yet granted (fresh install) OR explicitly revoked in Settings → Health → Data Access
- [ ] Watch app HealthKit auth not yet granted

## 1. Happy path
- [ ] Tap Start in WorkoutDetail on phone
- [ ] HealthKit auth modal appears on phone → tap Continue → grant in system prompt
- [ ] Watch joins, shows Active Set within ~3s
- [ ] Watch HK auth prompt appears on first launch → grant
- [ ] Tap "Set done" on Watch through every set in the workout
- [ ] Phone's LiveHRCardView shows real BPM (not "—") within 10s
- [ ] After last set, Watch shows "Done"; Phone navigates to Complete flow
- [ ] Open Apple Health → Workouts → today: exactly one new HKWorkout

## 2. Phone primary
- [ ] Start a fresh workout
- [ ] Log every set on the **Phone** (existing Plan 4 path)
- [ ] Watch reflects current exercise/set within ~1s
- [ ] Workout ends; HKWorkout written

## 3. Mixed
- [ ] Start a fresh workout
- [ ] Alternate Watch/Phone set logging across exercises
- [ ] No duplicate SetLogEntity rows (verify via debug panel or log)
- [ ] HKWorkout written

## 4. Watch unreachable
- [ ] Start workout normally
- [ ] After set 1 logged, put Phone in airplane mode
- [ ] Continue logging 3 sets on Watch
- [ ] Watch UI advances normally (UI state independent of phone reachability)
- [ ] Disable airplane mode
- [ ] Outbox drains within ~5s; Phone shows all 4 sets logged
- [ ] Workout ends; HKWorkout written

## 5. Phone-quit (mid-session resume)
- [ ] Start workout normally; log 2 sets
- [ ] Force-quit PulseApp on Phone (swipe up + flick)
- [ ] Continue logging 2 more sets on Watch
- [ ] Relaunch PulseApp on Phone
- [ ] Phone resumes directly into InWorkoutView (NOT Home or Onboarding)
- [ ] All 4 sets visible
- [ ] Finish workout normally; HKWorkout written

## 6. Watch-quit
- [ ] Start workout normally; log 2 sets
- [ ] Force-quit PulseWatch on Watch
- [ ] Relaunch PulseWatch
- [ ] Watch shows ActiveSetView for the next set (recovered)
- [ ] Continue logging; finish workout

## 7. HealthKit denial
- [ ] Settings → Health → Data Access → revoke Pulse write permissions on Phone
- [ ] Start workout
- [ ] Phone proceeds (workout saves to SwiftData; no HKWorkout written)
- [ ] Revoke also on Watch app
- [ ] Restart workout
- [ ] Watch sends `.failed(.healthKitDenied)`; Phone shows Home banner: "Watch declined HealthKit access — open the Watch app to enable."
- [ ] Dismiss banner; doesn't return until next denial
```

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/smoke
git commit -m "docs(plan-5): real-device smoke checklist with 7 ship-gate scenarios

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 17.2: Run the checklist; fix anything that fails

- [ ] **Step 1: Build + install on devices**

```bash
cd ios && xcodebuild -workspace PulseApp.xcodeproj/project.xcworkspace \
  -scheme PulseApp -destination 'id=<phone-udid>' install
xcodebuild -workspace PulseApp.xcodeproj/project.xcworkspace \
  -scheme PulseWatch -destination 'id=<watch-udid>' install
```

- [ ] **Step 2: Walk every scenario; check off boxes in `plan-5-watch-smoke.md` as a commit per pass**

For each fix discovered, commit it under the relevant Task Group's scope. Re-run only the affected scenarios after each fix.

- [ ] **Step 3: When all 7 are green, commit the filled-in checklist**

```bash
git add docs/superpowers/smoke/plan-5-watch-smoke.md
git commit -m "docs(plan-5): real-device smoke — all 7 scenarios green on iPhone 17 Pro + AW11

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 17.3: Run all `swift test` suites end-to-end

- [ ] **Step 1: Full test run**

```bash
for pkg in Logging WatchBridge Features/WatchWorkout Features/InWorkout Features/Home Repositories HealthKitClient AppShell; do
  ( cd "ios/Packages/$pkg" && swift test ) || { echo "FAIL: $pkg"; exit 1; }
done
```

Expected: all green.

- [ ] **Step 2: If any fails, fix root cause and commit per package**

- [ ] **Step 3: Push to origin**

```bash
git push origin main
```

---

# Done criteria

- [ ] All 17 task groups complete; tests green per package.
- [ ] All 7 real-device smoke scenarios green; checklist checked into git.
- [ ] One `HKWorkout` per completed session visible in Apple Health on real device.
- [ ] No silent `do { } catch { }` left in repository code touched by this plan.
- [ ] Pushed to `origin/main`.

When all of the above are met, Plan 5 ships. Plan 6 (coach voice + rest-timer notifications) and Plan 7 (Sentry + debug panel + XCUITest) follow.
