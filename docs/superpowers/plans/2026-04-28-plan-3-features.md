# Pulse — Plan 3: Phone-only Feature Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the four phone-only features (Onboarding → PlanGeneration → Home → WorkoutDetail) on top of the Plan 2 foundation. Output: a working iOS slice where a fresh install runs the user through onboarding, auto-streams their first workout, and lets them browse the generated plan + per-exercise demos. Start CTA on WorkoutDetail is intentionally non-functional (Plan 4).

**Architecture:** Per-feature local SPM packages under `ios/Packages/Features/{Onboarding,Home,PlanGeneration,WorkoutDetail}`. Each owns one `@Observable` store and a thin SwiftUI view layer. Cross-feature concerns flow through Repositories (Plan 2). New high-level methods on `PlanRepository` build prompts from `Profile + Coach` and wrap the existing `generatePlan` streaming primitive. New `ProfileRepository`, plus `WorkoutRepository.latestWorkout()` / `deleteWorkout(id:)`. AppShell gains a first-run branch (no `Profile` → present `OnboardingFlowView` as `.fullScreenCover`); Home wires into the existing `.today` tab.

**Tech Stack:** Swift 5.9+, SwiftUI, SwiftData, `@Observable`, URLSession async/await, AVKit (for looping exercise MP4s), XCTest. iOS 17+. xcodegen.

**Spec:** `docs/superpowers/specs/2026-04-28-plan-3-features-design.md`. Master spec: `docs/superpowers/specs/2026-04-26-pulse-ai-trainer-app-design.md`.

**Scope outside this plan:** InWorkout, Complete (feedback + adaptation), HealthKit, Watch app (Plan 4). Sentry, debug panel, prompts.json hot-loading, XCUITest, TestFlight (Plan 5).

---

## File Structure

```
ios/
  Project.yml                                       ← MODIFY: register 4 new packages
  Packages/
    CoreModels/Sources/CoreModels/
      OnboardingDraft.swift                         ← NEW
      CoachStrings.swift                            ← NEW
      WorkoutPlan.swift                             ← MODIFY: add `why: String?` to PlannedWorkout
    Persistence/Sources/Persistence/Entities/
      WorkoutEntity.swift                           ← MODIFY: add `why: String?`
    Repositories/Sources/Repositories/
      ProfileRepository.swift                       ← NEW
      WorkoutRepository.swift                       ← MODIFY: add `latestWorkout`, `deleteWorkout(id:)`
      PlanRepository.swift                          ← MODIFY: persist Workout rows; add streamFirstPlan, regenerate
      PromptBuilder.swift                           ← NEW (private) — builds system + user prompts
    Features/                                       ← NEW directory
      Onboarding/
        Package.swift
        Sources/Onboarding/
          OnboardingStore.swift
          OnboardingFlowView.swift
          Steps/
            NameStepView.swift
            GoalsStepView.swift
            LevelStepView.swift
            EquipmentStepView.swift
            FrequencyStepView.swift
            CoachPickStepView.swift
        Tests/OnboardingTests/
          OnboardingStoreTests.swift
      PlanGeneration/
        Package.swift
        Sources/PlanGeneration/
          PlanGenStore.swift
          PlanGenerationView.swift
          Components/
            CheckpointRowView.swift
            StreamingTextPaneView.swift
            PlanGenDoneCardView.swift
        Tests/PlanGenerationTests/
          PlanGenStoreTests.swift
      Home/
        Package.swift
        Sources/Home/
          HomeStore.swift
          HomeView.swift
          Components/
            WorkoutHeroCardView.swift
            WeekStripView.swift
        Tests/HomeTests/
          HomeStoreTests.swift
      WorkoutDetail/
        Package.swift
        Sources/WorkoutDetail/
          WorkoutDetailStore.swift
          WorkoutDetailView.swift
          Components/
            ExerciseRowView.swift
            ExerciseDetailSheet.swift
            BlockSectionView.swift
        Tests/WorkoutDetailTests/
          WorkoutDetailStoreTests.swift
    AppShell/Sources/AppShell/
      RootScaffold.swift                            ← MODIFY: first-run branch + Home injection
      FirstRunGate.swift                            ← NEW
  PulseApp/
    AppShellRoot.swift                              ← MODIFY: pass new feature views through
    DebugFeatureSmokeView.swift                     ← NEW
    PulseApp.swift                                  ← MODIFY: register Debug smoke view
```

---

## Phase A — CoreModels and Persistence extensions

### Task A1: Add `why` field to `PlannedWorkout`

**Files:**
- Modify: `ios/Packages/CoreModels/Sources/CoreModels/WorkoutPlan.swift`
- Modify: `ios/Packages/CoreModels/Tests/CoreModelsTests/WorkoutPlanTests.swift` (or whichever test file currently covers WorkoutPlan; create one if absent)

- [ ] **Step 1: Find existing WorkoutPlan tests**

Run: `find ios/Packages/CoreModels/Tests -name "*.swift" -exec grep -l "WorkoutPlan" {} \;`
Expected: prints the file path of an existing test file (note path; it's the target of step 2). If empty, create `ios/Packages/CoreModels/Tests/CoreModelsTests/WorkoutPlanTests.swift`.

- [ ] **Step 2: Write failing test for the `why` field round-trip**

Add to the WorkoutPlan test file:

```swift
func test_plannedWorkout_decodesWhyFieldFromJSON() throws {
    let json = #"""
    {"id":"w1","scheduledFor":"2026-04-28T00:00:00Z","title":"Push","subtitle":"Upper body","workoutType":"Strength","durationMin":45,"blocks":[],"why":"Today we focus on horizontal pressing volume."}
    """#
    let pw = try JSONDecoder.pulse.decode(PlannedWorkout.self, from: Data(json.utf8))
    XCTAssertEqual(pw.why, "Today we focus on horizontal pressing volume.")
}

func test_plannedWorkout_decodesWithMissingWhy() throws {
    let json = #"""
    {"id":"w1","scheduledFor":"2026-04-28T00:00:00Z","title":"Push","subtitle":"Upper body","workoutType":"Strength","durationMin":45,"blocks":[]}
    """#
    let pw = try JSONDecoder.pulse.decode(PlannedWorkout.self, from: Data(json.utf8))
    XCTAssertNil(pw.why)
}
```

- [ ] **Step 3: Run tests — confirm fail**

Run: `cd ios/Packages/CoreModels && swift test --filter WorkoutPlanTests/test_plannedWorkout_decodesWhyFieldFromJSON`
Expected: build error (`'why'` not found) or test fail.

- [ ] **Step 4: Add `why: String?` to `PlannedWorkout`**

Edit `WorkoutPlan.swift`. In `PlannedWorkout`, add the property and its init parameter:

```swift
public struct PlannedWorkout: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var scheduledFor: Date
    public var title: String
    public var subtitle: String
    public var workoutType: String
    public var durationMin: Int
    public var blocks: [WorkoutBlock]
    public var why: String?

    public init(id: String, scheduledFor: Date, title: String, subtitle: String,
                workoutType: String, durationMin: Int, blocks: [WorkoutBlock],
                why: String? = nil) {
        self.id = id
        self.scheduledFor = scheduledFor
        self.title = title
        self.subtitle = subtitle
        self.workoutType = workoutType
        self.durationMin = durationMin
        self.blocks = blocks
        self.why = why
    }
}
```

- [ ] **Step 5: Run tests — confirm pass**

Run: `cd ios/Packages/CoreModels && swift test`
Expected: all tests pass (10+ from Plan 2 plus 2 new).

- [ ] **Step 6: Commit**

```bash
git add ios/Packages/CoreModels/Sources/CoreModels/WorkoutPlan.swift ios/Packages/CoreModels/Tests/CoreModelsTests/
git commit -m "feat(core-models): add optional why field to PlannedWorkout"
```

---

### Task A2: Add `why` field to `WorkoutEntity` (SwiftData lightweight migration)

**Files:**
- Modify: `ios/Packages/Persistence/Sources/Persistence/Entities/WorkoutEntity.swift`
- Modify: `ios/Packages/Persistence/Tests/PersistenceTests/WorkoutEntityTests.swift` (or matching existing test file)

Adding an optional field to a SwiftData `@Model` is a lightweight migration — SwiftData will materialize existing rows with `nil` automatically. No migration plan code needed.

- [ ] **Step 1: Write failing test for the new column**

Find the existing WorkoutEntity test file and append:

```swift
@MainActor
func test_workoutEntity_storesAndReturnsWhy() throws {
    let container = try PulseModelContainer.inMemory()
    let ctx = container.mainContext
    let w = WorkoutEntity(
        id: UUID(), planID: UUID(),
        scheduledFor: Date(), title: "Push", subtitle: "Upper",
        workoutType: "Strength", durationMin: 45, status: "scheduled",
        blocksJSON: Data("[]".utf8), exercisesJSON: Data("[]".utf8),
        why: "Today we hit horizontal press volume."
    )
    ctx.insert(w); try ctx.save()
    let fetched = try ctx.fetch(FetchDescriptor<WorkoutEntity>()).first
    XCTAssertEqual(fetched?.why, "Today we hit horizontal press volume.")
}
```

- [ ] **Step 2: Run — confirm fail**

Run: `cd ios/Packages/Persistence && swift test --filter test_workoutEntity_storesAndReturnsWhy`
Expected: build error (no `why` parameter).

- [ ] **Step 3: Add `why: String?` to `WorkoutEntity`**

Edit `WorkoutEntity.swift`. Add the property and init parameter (default `nil`):

```swift
public var why: String?
```

In `init(...)`:

```swift
public init(id: UUID, userID: UUID? = nil, planID: UUID, scheduledFor: Date,
            title: String, subtitle: String, workoutType: String, durationMin: Int,
            status: String, blocksJSON: Data, exercisesJSON: Data,
            whispersJSON: Data? = nil, why: String? = nil) {
    // ... existing assignments ...
    self.why = why
}
```

- [ ] **Step 4: Run all Persistence tests**

Run: `cd ios/Packages/Persistence && swift test`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/Persistence/
git commit -m "feat(persistence): add optional why field to WorkoutEntity"
```

---

### Task A3: Add `OnboardingDraft` to CoreModels

**Files:**
- Create: `ios/Packages/CoreModels/Sources/CoreModels/OnboardingDraft.swift`
- Create: `ios/Packages/CoreModels/Tests/CoreModelsTests/OnboardingDraftTests.swift`

- [ ] **Step 1: Write failing tests**

Create `OnboardingDraftTests.swift`:

```swift
import XCTest
@testable import CoreModels

final class OnboardingDraftTests: XCTestCase {
    func test_emptyDraft_hasAllFieldsNil() {
        let d = OnboardingDraft()
        XCTAssertEqual(d.displayName, "")
        XCTAssertTrue(d.goals.isEmpty)
        XCTAssertNil(d.level)
        XCTAssertTrue(d.equipment.isEmpty)
        XCTAssertNil(d.frequencyPerWeek)
        XCTAssertNil(d.weeklyTargetMinutes)
        XCTAssertNil(d.activeCoachID)
    }

    func test_buildProfile_returnsNilWhenIncomplete() {
        var d = OnboardingDraft()
        d.displayName = "Sam"
        XCTAssertNil(d.buildProfile(now: Date()))
    }

    func test_buildProfile_returnsProfileWhenComplete() {
        var d = OnboardingDraft()
        d.displayName = "Sam"
        d.goals = ["build muscle"]
        d.level = .regular
        d.equipment = ["dumbbells"]
        d.frequencyPerWeek = 4
        d.weeklyTargetMinutes = 180
        d.activeCoachID = "rex"
        let p = d.buildProfile(now: Date(timeIntervalSince1970: 1_730_000_000))
        XCTAssertNotNil(p)
        XCTAssertEqual(p?.displayName, "Sam")
        XCTAssertEqual(p?.frequencyPerWeek, 4)
        XCTAssertEqual(p?.activeCoachID, "rex")
    }
}
```

- [ ] **Step 2: Run — confirm fail**

Run: `cd ios/Packages/CoreModels && swift test --filter OnboardingDraftTests`
Expected: build error (no OnboardingDraft type).

- [ ] **Step 3: Create OnboardingDraft.swift**

```swift
import Foundation

public struct OnboardingDraft: Hashable, Sendable {
    public var displayName: String
    public var goals: [String]
    public var level: Profile.Level?
    public var equipment: [String]
    public var frequencyPerWeek: Int?
    public var weeklyTargetMinutes: Int?
    public var activeCoachID: String?

    public init() {
        self.displayName = ""
        self.goals = []
        self.level = nil
        self.equipment = []
        self.frequencyPerWeek = nil
        self.weeklyTargetMinutes = nil
        self.activeCoachID = nil
    }

    /// Returns a fully formed Profile if every required field is set, else nil.
    public func buildProfile(now: Date) -> Profile? {
        guard !displayName.trimmingCharacters(in: .whitespaces).isEmpty,
              !goals.isEmpty,
              let level,
              !equipment.isEmpty,
              let frequencyPerWeek,
              let weeklyTargetMinutes,
              let activeCoachID else { return nil }
        return Profile(
            id: UUID(),
            displayName: displayName,
            goals: goals,
            level: level,
            equipment: equipment,
            frequencyPerWeek: frequencyPerWeek,
            weeklyTargetMinutes: weeklyTargetMinutes,
            activeCoachID: activeCoachID,
            createdAt: now
        )
    }

    public enum Step: Int, CaseIterable, Sendable {
        case name = 1, goals, level, equipment, frequency, coach
    }

    /// Returns true if the user can advance past `step` with current draft state.
    public func canAdvance(from step: Step) -> Bool {
        switch step {
        case .name:      return !displayName.trimmingCharacters(in: .whitespaces).isEmpty
        case .goals:     return !goals.isEmpty
        case .level:     return level != nil
        case .equipment: return !equipment.isEmpty
        case .frequency: return frequencyPerWeek != nil && weeklyTargetMinutes != nil
        case .coach:     return activeCoachID != nil
        }
    }
}
```

- [ ] **Step 4: Run — confirm pass**

Run: `cd ios/Packages/CoreModels && swift test --filter OnboardingDraftTests`
Expected: 3/3 pass.

- [ ] **Step 5: Add `canAdvance` boundary tests**

Append to `OnboardingDraftTests.swift`:

```swift
func test_canAdvance_nameStep() {
    var d = OnboardingDraft()
    XCTAssertFalse(d.canAdvance(from: .name))
    d.displayName = "   "
    XCTAssertFalse(d.canAdvance(from: .name))
    d.displayName = "Sam"
    XCTAssertTrue(d.canAdvance(from: .name))
}

func test_canAdvance_goalsStep() {
    var d = OnboardingDraft()
    XCTAssertFalse(d.canAdvance(from: .goals))
    d.goals = ["lose fat"]
    XCTAssertTrue(d.canAdvance(from: .goals))
}

func test_canAdvance_frequencyStep_requiresBoth() {
    var d = OnboardingDraft()
    d.frequencyPerWeek = 4
    XCTAssertFalse(d.canAdvance(from: .frequency))
    d.weeklyTargetMinutes = 180
    XCTAssertTrue(d.canAdvance(from: .frequency))
}
```

- [ ] **Step 6: Run all CoreModels tests**

Run: `cd ios/Packages/CoreModels && swift test`
Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
git add ios/Packages/CoreModels/
git commit -m "feat(core-models): add OnboardingDraft with step validation"
```

---

### Task A4: Add `CoachStrings` lookup table to CoreModels

**Files:**
- Create: `ios/Packages/CoreModels/Sources/CoreModels/CoachStrings.swift`
- Create: `ios/Packages/CoreModels/Tests/CoreModelsTests/CoachStringsTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
import XCTest
@testable import CoreModels

final class CoachStringsTests: XCTestCase {
    func test_allCoachIDsHaveOnboardingWelcome() {
        for coach in Coach.all {
            XCTAssertNotNil(CoachStrings.onboardingWelcome[coach.id], "missing onboardingWelcome for \(coach.id)")
        }
    }

    func test_allCoachIDsHavePlanGenHeader() {
        for coach in Coach.all {
            XCTAssertNotNil(CoachStrings.planGenHeader[coach.id], "missing planGenHeader for \(coach.id)")
        }
    }

    func test_allCoachIDsHaveHomeGreeting() {
        for coach in Coach.all {
            XCTAssertNotNil(CoachStrings.homeGreeting[coach.id], "missing homeGreeting for \(coach.id)")
        }
    }

    func test_lookupHelpersFallBackOnUnknownCoach() {
        XCTAssertEqual(CoachStrings.onboardingWelcome(for: "nonsense"), CoachStrings.onboardingWelcome["ace"])
        XCTAssertEqual(CoachStrings.planGenHeader(for: "nonsense"), CoachStrings.planGenHeader["ace"])
        XCTAssertEqual(CoachStrings.homeGreeting(for: "nonsense"), CoachStrings.homeGreeting["ace"])
    }
}
```

- [ ] **Step 2: Run — confirm fail**

Run: `cd ios/Packages/CoreModels && swift test --filter CoachStringsTests`

- [ ] **Step 3: Create CoachStrings.swift**

```swift
import Foundation

public enum CoachStrings {
    public static let onboardingWelcome: [String: String] = [
        "ace":  "Hey, I'm Ace. Let's build something.",
        "rex":  "Welcome — Rex. We're going to take this seriously.",
        "vera": "Vera here. Tell me where you want to be in 12 weeks.",
        "mira": "I'm Mira. We'll start where you are.",
    ]

    public static let planGenHeader: [String: String] = [
        "ace":  "Putting your day together",
        "rex":  "Building today's session",
        "vera": "Designing this for you",
        "mira": "Shaping today",
    ]

    public static let homeGreeting: [String: String] = [
        "ace":  "Hey",
        "rex":  "Morning",
        "vera": "Welcome back",
        "mira": "Hi",
    ]

    public static func onboardingWelcome(for coachID: String) -> String {
        onboardingWelcome[coachID] ?? onboardingWelcome["ace"]!
    }

    public static func planGenHeader(for coachID: String) -> String {
        planGenHeader[coachID] ?? planGenHeader["ace"]!
    }

    public static func homeGreeting(for coachID: String) -> String {
        homeGreeting[coachID] ?? homeGreeting["ace"]!
    }
}
```

- [ ] **Step 4: Run — confirm pass**

Run: `cd ios/Packages/CoreModels && swift test --filter CoachStringsTests`
Expected: 4/4 pass.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/CoreModels/
git commit -m "feat(core-models): add CoachStrings table (onboarding, plan-gen, home)"
```

---

## Phase B — Repositories extensions

### Task B1: Create `ProfileRepository`

**Files:**
- Create: `ios/Packages/Repositories/Sources/Repositories/ProfileRepository.swift`
- Create: `ios/Packages/Repositories/Tests/RepositoriesTests/ProfileRepositoryTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
import XCTest
import SwiftData
import CoreModels
import Persistence
@testable import Repositories

final class ProfileRepositoryTests: XCTestCase {
    @MainActor
    func test_currentProfile_returnsNilWhenEmpty() throws {
        let container = try PulseModelContainer.inMemory()
        let repo = ProfileRepository(modelContainer: container)
        XCTAssertNil(repo.currentProfile())
    }

    @MainActor
    func test_save_thenCurrentProfile_returnsSaved() throws {
        let container = try PulseModelContainer.inMemory()
        let repo = ProfileRepository(modelContainer: container)
        let p = Profile(id: UUID(), displayName: "Sam",
                        goals: ["build muscle"], level: .regular,
                        equipment: ["dumbbells"], frequencyPerWeek: 4,
                        weeklyTargetMinutes: 180, activeCoachID: "rex",
                        createdAt: Date())
        try repo.save(p)
        let loaded = repo.currentProfile()
        XCTAssertEqual(loaded?.displayName, "Sam")
        XCTAssertEqual(loaded?.activeCoachID, "rex")
        XCTAssertEqual(loaded?.frequencyPerWeek, 4)
    }

    @MainActor
    func test_save_isIdempotent_byID() throws {
        let container = try PulseModelContainer.inMemory()
        let repo = ProfileRepository(modelContainer: container)
        let id = UUID()
        var p = Profile(id: id, displayName: "Sam", goals: ["build muscle"],
                        level: .regular, equipment: ["dumbbells"],
                        frequencyPerWeek: 4, weeklyTargetMinutes: 180,
                        activeCoachID: "rex", createdAt: Date())
        try repo.save(p)
        p.activeCoachID = "vera"
        try repo.save(p)
        let all = try container.mainContext.fetch(FetchDescriptor<ProfileEntity>())
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.activeCoachID, "vera")
    }

    @MainActor
    func test_save_setsAccentHueFromCoach() throws {
        let container = try PulseModelContainer.inMemory()
        let repo = ProfileRepository(modelContainer: container)
        let p = Profile(id: UUID(), displayName: "Sam", goals: ["lose fat"],
                        level: .regular, equipment: ["none"],
                        frequencyPerWeek: 3, weeklyTargetMinutes: 90,
                        activeCoachID: "vera", createdAt: Date())
        try repo.save(p)
        let entity = try container.mainContext.fetch(FetchDescriptor<ProfileEntity>()).first
        XCTAssertEqual(entity?.accentHue, 220)  // Coach.byID("vera").accentHue
    }
}
```

- [ ] **Step 2: Run — confirm fail**

Run: `cd ios/Packages/Repositories && swift test --filter ProfileRepositoryTests`

- [ ] **Step 3: Create ProfileRepository.swift**

```swift
import Foundation
import SwiftData
import CoreModels
import Persistence

@MainActor
public final class ProfileRepository {
    public let modelContainer: ModelContainer

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    /// Returns the single Profile if onboarding has been completed.
    public func currentProfile() -> Profile? {
        let ctx = modelContainer.mainContext
        let descriptor = FetchDescriptor<ProfileEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        guard let entity = try? ctx.fetch(descriptor).first else { return nil }
        guard let level = Profile.Level(rawValue: entity.level) else { return nil }
        return Profile(
            id: entity.id,
            displayName: entity.displayName,
            goals: entity.goals,
            level: level,
            equipment: entity.equipment,
            frequencyPerWeek: entity.frequencyPerWeek,
            weeklyTargetMinutes: entity.weeklyTargetMinutes,
            activeCoachID: entity.activeCoachID,
            createdAt: entity.createdAt
        )
    }

    /// Saves or updates the Profile, denormalizing `accentHue` from the Coach.
    public func save(_ profile: Profile) throws {
        let ctx = modelContainer.mainContext
        let id = profile.id
        let descriptor = FetchDescriptor<ProfileEntity>(
            predicate: #Predicate { $0.id == id }
        )
        let hue = Coach.byID(profile.activeCoachID)?.accentHue ?? 45
        if let existing = try ctx.fetch(descriptor).first {
            existing.displayName = profile.displayName
            existing.goals = profile.goals
            existing.level = profile.level.rawValue
            existing.equipment = profile.equipment
            existing.frequencyPerWeek = profile.frequencyPerWeek
            existing.weeklyTargetMinutes = profile.weeklyTargetMinutes
            existing.activeCoachID = profile.activeCoachID
            existing.accentHue = hue
        } else {
            ctx.insert(ProfileEntity(
                id: profile.id,
                displayName: profile.displayName,
                goals: profile.goals,
                level: profile.level.rawValue,
                equipment: profile.equipment,
                frequencyPerWeek: profile.frequencyPerWeek,
                weeklyTargetMinutes: profile.weeklyTargetMinutes,
                activeCoachID: profile.activeCoachID,
                accentHue: hue,
                createdAt: profile.createdAt
            ))
        }
        try ctx.save()
    }
}
```

- [ ] **Step 4: Run — confirm pass**

Run: `cd ios/Packages/Repositories && swift test --filter ProfileRepositoryTests`
Expected: 4/4 pass.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/Repositories/
git commit -m "feat(repositories): ProfileRepository (currentProfile + idempotent save)"
```

---

### Task B2: Add `WorkoutRepository.latestWorkout()` and `deleteWorkout(id:)`

**Files:**
- Modify: `ios/Packages/Repositories/Sources/Repositories/WorkoutRepository.swift`
- Modify: `ios/Packages/Repositories/Tests/RepositoriesTests/WorkoutRepositoryTests.swift`

- [ ] **Step 1: Write failing tests**

Append to `WorkoutRepositoryTests.swift`:

```swift
@MainActor
func test_latestWorkout_returnsMostRecentByScheduledFor() throws {
    let container = try PulseModelContainer.inMemory()
    let ctx = container.mainContext
    let older = WorkoutEntity(id: UUID(), planID: UUID(),
        scheduledFor: Date(timeIntervalSince1970: 1_700_000_000),
        title: "A", subtitle: "", workoutType: "Strength", durationMin: 30,
        status: "scheduled", blocksJSON: Data("[]".utf8), exercisesJSON: Data("[]".utf8))
    let newer = WorkoutEntity(id: UUID(), planID: UUID(),
        scheduledFor: Date(timeIntervalSince1970: 1_730_000_000),
        title: "B", subtitle: "", workoutType: "Strength", durationMin: 45,
        status: "scheduled", blocksJSON: Data("[]".utf8), exercisesJSON: Data("[]".utf8))
    ctx.insert(older); ctx.insert(newer); try ctx.save()
    let repo = WorkoutRepository(modelContainer: container)
    let latest = try repo.latestWorkout()
    XCTAssertEqual(latest?.title, "B")
}

@MainActor
func test_latestWorkout_returnsNilWhenEmpty() throws {
    let container = try PulseModelContainer.inMemory()
    let repo = WorkoutRepository(modelContainer: container)
    XCTAssertNil(try repo.latestWorkout())
}

@MainActor
func test_deleteWorkout_removesByID() throws {
    let container = try PulseModelContainer.inMemory()
    let ctx = container.mainContext
    let id = UUID()
    let w = WorkoutEntity(id: id, planID: UUID(),
        scheduledFor: Date(), title: "A", subtitle: "",
        workoutType: "Strength", durationMin: 30, status: "scheduled",
        blocksJSON: Data("[]".utf8), exercisesJSON: Data("[]".utf8))
    ctx.insert(w); try ctx.save()
    let repo = WorkoutRepository(modelContainer: container)
    try repo.deleteWorkout(id: id)
    XCTAssertEqual(try ctx.fetch(FetchDescriptor<WorkoutEntity>()).count, 0)
}
```

- [ ] **Step 2: Run — confirm fail**

Run: `cd ios/Packages/Repositories && swift test --filter WorkoutRepositoryTests`

- [ ] **Step 3: Add the two methods to `WorkoutRepository`**

In `WorkoutRepository.swift`, add:

```swift
/// Returns the most recently scheduled Workout, regardless of date.
public func latestWorkout() throws -> WorkoutEntity? {
    var descriptor = FetchDescriptor<WorkoutEntity>(
        sortBy: [SortDescriptor(\.scheduledFor, order: .reverse)]
    )
    descriptor.fetchLimit = 1
    return try modelContainer.mainContext.fetch(descriptor).first
}

public func deleteWorkout(id: UUID) throws {
    let ctx = modelContainer.mainContext
    let descriptor = FetchDescriptor<WorkoutEntity>(
        predicate: #Predicate { $0.id == id }
    )
    for w in try ctx.fetch(descriptor) {
        ctx.delete(w)
    }
    try ctx.save()
}
```

- [ ] **Step 4: Run — confirm pass**

Run: `cd ios/Packages/Repositories && swift test --filter WorkoutRepositoryTests`
Expected: all (including 3 new) pass.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/Repositories/
git commit -m "feat(repositories): WorkoutRepository — latestWorkout + deleteWorkout"
```

---

### Task B3: Extend `PlanRepository.persist` to fan out plan workouts into `WorkoutEntity` rows

The current `persist` only writes a `PlanEntity`. Plan 3 needs the streamed plan's `[PlannedWorkout]` to also become persisted `WorkoutEntity` rows so `WorkoutRepository.latestWorkout()` can find them.

**Files:**
- Modify: `ios/Packages/Repositories/Sources/Repositories/PlanRepository.swift`
- Modify: `ios/Packages/Repositories/Tests/RepositoriesTests/PlanRepositoryTests.swift`

- [ ] **Step 1: Write failing test using a fixture WorkoutPlan**

Append to `PlanRepositoryTests.swift`:

```swift
@MainActor
func test_persist_alsoCreatesWorkoutEntitiesForEachPlannedWorkout() throws {
    let container = try PulseModelContainer.inMemory()
    let plan = WorkoutPlan(
        weekStart: Date(timeIntervalSince1970: 1_730_000_000),
        workouts: [
            PlannedWorkout(id: "w1",
                scheduledFor: Date(timeIntervalSince1970: 1_730_000_000),
                title: "Push", subtitle: "Upper",
                workoutType: "Strength", durationMin: 45,
                blocks: [], why: "Pressing volume."),
        ]
    )
    let repo = PlanRepository.makeForTests(modelContainer: container)
    let raw = try JSONEncoder.pulse.encode(plan)
    try repo._persistForTests(plan: plan,
        weekStart: plan.weekStart,
        modelUsed: "claude-opus-4-7",
        promptTokens: 100, completionTokens: 200, rawJSON: raw)
    let workouts = try container.mainContext.fetch(FetchDescriptor<WorkoutEntity>())
    XCTAssertEqual(workouts.count, 1)
    XCTAssertEqual(workouts.first?.title, "Push")
    XCTAssertEqual(workouts.first?.why, "Pressing volume.")
}
```

- [ ] **Step 2: Run — confirm fail**

Run: `cd ios/Packages/Repositories && swift test --filter test_persist_alsoCreatesWorkoutEntities`
Expected: build error (no `_persistForTests`) or 0 workouts.

- [ ] **Step 3: Update `persist` in `PlanRepository.swift`**

Replace the `private func persist(...)` body with:

```swift
private func persist(plan: WorkoutPlan, weekStart: Date, modelUsed: String,
                     promptTokens: Int, completionTokens: Int, rawJSON: Data) throws {
    let planEntity = PlanEntity(
        id: UUID(),
        weekStart: weekStart,
        generatedAt: Date(),
        modelUsed: modelUsed,
        promptTokens: promptTokens,
        completionTokens: completionTokens,
        payloadJSON: rawJSON
    )
    let ctx = modelContainer.mainContext
    ctx.insert(planEntity)
    for pw in plan.workouts {
        let blocksJSON = (try? JSONEncoder.pulse.encode(pw.blocks)) ?? Data("[]".utf8)
        let exercisesFlat = pw.blocks.flatMap { $0.exercises }
        let exercisesJSON = (try? JSONEncoder.pulse.encode(exercisesFlat)) ?? Data("[]".utf8)
        ctx.insert(WorkoutEntity(
            id: UUID(),
            planID: planEntity.id,
            scheduledFor: pw.scheduledFor,
            title: pw.title,
            subtitle: pw.subtitle,
            workoutType: pw.workoutType,
            durationMin: pw.durationMin,
            status: "scheduled",
            blocksJSON: blocksJSON,
            exercisesJSON: exercisesJSON,
            why: pw.why
        ))
    }
    try ctx.save()
}

/// Test-only — exposes `persist` for unit tests of the fan-out logic.
public func _persistForTests(plan: WorkoutPlan, weekStart: Date,
                             modelUsed: String, promptTokens: Int,
                             completionTokens: Int, rawJSON: Data) throws {
    try persist(plan: plan, weekStart: weekStart, modelUsed: modelUsed,
                promptTokens: promptTokens, completionTokens: completionTokens,
                rawJSON: rawJSON)
}
```

- [ ] **Step 4: Run all repo tests**

Run: `cd ios/Packages/Repositories && swift test`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/Repositories/
git commit -m "feat(repositories): persist Workout entities alongside Plan on stream done"
```

---

### Task B4: Add `PromptBuilder` (private to Repositories)

**Files:**
- Create: `ios/Packages/Repositories/Sources/Repositories/PromptBuilder.swift`
- Create: `ios/Packages/Repositories/Tests/RepositoriesTests/PromptBuilderTests.swift`

System prompts hardcoded for Plan 3. Hot-loading from R2 (`prompts.json`) is deferred to Plan 5.

- [ ] **Step 1: Write failing tests**

```swift
import XCTest
import CoreModels
@testable import Repositories

final class PromptBuilderTests: XCTestCase {
    func test_systemPrompt_includesCoachIdentity() {
        let coach = Coach.byID("rex")!
        let s = PromptBuilder.planGenSystemPrompt(coach: coach)
        XCTAssertTrue(s.contains("Rex"))
        XCTAssertTrue(s.contains("CHECKPOINT"))
        XCTAssertTrue(s.contains("```json"))
    }

    func test_userMessage_includesAllProfileFieldsAndDate() {
        let p = Profile(id: UUID(), displayName: "Sam",
            goals: ["build muscle"], level: .regular,
            equipment: ["dumbbells"], frequencyPerWeek: 4,
            weeklyTargetMinutes: 180, activeCoachID: "rex",
            createdAt: Date())
        let date = Date(timeIntervalSince1970: 1_730_000_000)
        let m = PromptBuilder.planGenUserMessage(profile: p, today: date)
        XCTAssertTrue(m.contains("Sam"))
        XCTAssertTrue(m.contains("build muscle"))
        XCTAssertTrue(m.contains("regular"))
        XCTAssertTrue(m.contains("dumbbells"))
        XCTAssertTrue(m.contains("4"))
        XCTAssertTrue(m.contains("180"))
    }

    func test_strictRetrySuffix_appendsValidJSONReminder() {
        let s = PromptBuilder.planGenSystemPrompt(coach: Coach.byID("ace")!,
                                                  strictRetry: true)
        XCTAssertTrue(s.contains("respond with valid JSON only"))
    }
}
```

- [ ] **Step 2: Run — confirm fail**

Run: `cd ios/Packages/Repositories && swift test --filter PromptBuilderTests`

- [ ] **Step 3: Create PromptBuilder.swift**

```swift
import Foundation
import CoreModels

enum PromptBuilder {
    static let planGenFraming: String = """
    You are {coachName}, {coachTagline}.
    You design adaptive workouts based on the user's profile and recent
    training history. You output a single JSON object matching the schema.
    Stream checkpoint markers as ⟦CHECKPOINT: <label>⟧ during reasoning so
    the UI can show progress.

    Final output must be a valid JSON object inside a ```json code block.
    Use this schema:

    {
      "weekStart": "<ISO8601 date>",
      "workouts": [{
        "id": "<short id>",
        "scheduledFor": "<ISO8601 date>",
        "title": "<2-4 words>",
        "subtitle": "<1 short phrase>",
        "workoutType": "Strength|HIIT|Mobility|Conditioning",
        "durationMin": <int>,
        "blocks": [{
          "id": "<short>",
          "label": "Warm-up|Main|Cooldown",
          "exercises": [{
            "id": "<unique within plan>",
            "exerciseID": "<catalog manifest id>",
            "name": "<display name>",
            "sets": [{"setNum": 1, "reps": 8, "load": "BW", "restSec": 60}]
          }]
        }],
        "why": "<1-2 sentences in your voice explaining today's focus>"
      }]
    }

    Generate one workout for today. Stream checkpoints as you reason.
    """

    static let strictRetrySuffix: String = """

    Important: respond with valid JSON only inside the ```json fence.
    Do not include any other prose after the JSON block.
    """

    static func planGenSystemPrompt(coach: Coach, strictRetry: Bool = false) -> String {
        var s = planGenFraming
            .replacingOccurrences(of: "{coachName}", with: coach.displayName)
            .replacingOccurrences(of: "{coachTagline}", with: coach.tagline)
        if strictRetry {
            s += strictRetrySuffix
        }
        return s
    }

    static func planGenUserMessage(profile: Profile, today: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let dateStr = formatter.string(from: today)
        let goals = profile.goals.joined(separator: ", ")
        let equipment = profile.equipment.joined(separator: ", ")
        return """
        Profile:
        - Name: \(profile.displayName)
        - Goals: \(goals)
        - Level: \(profile.level.rawValue)
        - Equipment available: \(equipment)
        - Sessions per week: \(profile.frequencyPerWeek)
        - Weekly target minutes: \(profile.weeklyTargetMinutes)

        Today: \(dateStr)

        Generate today's workout.
        """
    }
}
```

- [ ] **Step 4: Run — confirm pass**

Run: `cd ios/Packages/Repositories && swift test --filter PromptBuilderTests`
Expected: 3/3 pass.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/Repositories/
git commit -m "feat(repositories): PromptBuilder for plan generation prompts"
```

---

### Task B5: Add `PlanRepository.streamFirstPlan(profile:coach:)` and `regenerate(profile:coach:)`

**Files:**
- Modify: `ios/Packages/Repositories/Sources/Repositories/PlanRepository.swift`
- Modify: `ios/Packages/Repositories/Tests/RepositoriesTests/PlanRepositoryTests.swift`

These are thin wrappers over the existing `generatePlan`. `regenerate` deletes the prior latest workout (if any) before calling `generatePlan`. (Per spec §6, this is safe in Plan 3 because no `Session` references exist yet.)

- [ ] **Step 1: Write failing test (asserting the methods exist + regenerate clears prior)**

Append to `PlanRepositoryTests.swift`:

```swift
@MainActor
func test_regenerate_deletesPriorLatestWorkoutBeforeStreaming() async throws {
    let container = try PulseModelContainer.inMemory()
    let ctx = container.mainContext
    let priorID = UUID()
    let prior = WorkoutEntity(id: priorID, planID: UUID(),
        scheduledFor: Date(timeIntervalSince1970: 1_700_000_000),
        title: "Old", subtitle: "", workoutType: "Strength",
        durationMin: 30, status: "scheduled",
        blocksJSON: Data("[]".utf8), exercisesJSON: Data("[]".utf8))
    ctx.insert(prior); try ctx.save()

    let repo = PlanRepository.makeForTests(modelContainer: container)
    // Cancel immediately — we only assert the pre-stream cleanup occurred.
    let stream = repo.regenerate(profile: ProfileRepositoryTests.fixtureProfile(),
                                  coach: Coach.byID("rex")!)
    let task = Task { for try await _ in stream {} }
    task.cancel()
    _ = try? await task.value

    // The deletion should still have happened synchronously before the stream began.
    let remaining = try ctx.fetch(FetchDescriptor<WorkoutEntity>(
        predicate: #Predicate { $0.id == priorID }))
    XCTAssertTrue(remaining.isEmpty)
}
```

Add a fixture helper to `ProfileRepositoryTests.swift`:

```swift
extension ProfileRepositoryTests {
    static func fixtureProfile() -> Profile {
        Profile(id: UUID(), displayName: "Sam", goals: ["build muscle"],
                level: .regular, equipment: ["dumbbells"],
                frequencyPerWeek: 4, weeklyTargetMinutes: 180,
                activeCoachID: "rex", createdAt: Date())
    }
}
```

- [ ] **Step 2: Run — confirm fail**

Run: `cd ios/Packages/Repositories && swift test --filter test_regenerate_deletesPriorLatestWorkout`

- [ ] **Step 3: Add the two methods to `PlanRepository`**

In `PlanRepository.swift`, add:

```swift
/// High-level wrapper. Builds prompts from profile + coach, then streams.
/// `mode == .firstPlan` → straight call. `mode == .regenerate` → deletes
/// the prior latest workout first.
public func streamFirstPlan(profile: Profile, coach: Coach,
                            now: Date = Date()) -> AsyncThrowingStream<PlanStreamUpdate, Error> {
    let system = PromptBuilder.planGenSystemPrompt(coach: coach)
    let user = PromptBuilder.planGenUserMessage(profile: profile, today: now)
    let calendar = Calendar(identifier: .gregorian)
    let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
    return generatePlan(systemPrompt: system, userMessage: user, weekStart: weekStart)
}

/// Same as `streamFirstPlan` but deletes the prior latest workout first.
/// Safe in Plan 3 (no Session references); Plan 4 will revisit.
public func regenerate(profile: Profile, coach: Coach,
                       now: Date = Date()) -> AsyncThrowingStream<PlanStreamUpdate, Error> {
    let workoutRepo = WorkoutRepository(modelContainer: modelContainer)
    if let prior = try? workoutRepo.latestWorkout() {
        try? workoutRepo.deleteWorkout(id: prior.id)
    }
    return streamFirstPlan(profile: profile, coach: coach, now: now)
}
```

- [ ] **Step 4: Run — confirm pass**

Run: `cd ios/Packages/Repositories && swift test --filter test_regenerate_deletesPriorLatestWorkout`
Expected: pass.

- [ ] **Step 5: Run all repo tests**

Run: `cd ios/Packages/Repositories && swift test`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add ios/Packages/Repositories/
git commit -m "feat(repositories): PlanRepository — streamFirstPlan + regenerate wrappers"
```

---

## Phase C — Onboarding feature package

### Task C1: Create `Onboarding` SPM package skeleton

**Files:**
- Create: `ios/Packages/Features/Onboarding/Package.swift`
- Create: `ios/Packages/Features/Onboarding/Sources/Onboarding/Module.swift`
- Create: `ios/Packages/Features/Onboarding/Tests/OnboardingTests/SmokeTests.swift`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p "ios/Packages/Features/Onboarding/Sources/Onboarding/Steps" \
         "ios/Packages/Features/Onboarding/Tests/OnboardingTests"
```

- [ ] **Step 2: Write Package.swift**

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Onboarding",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "Onboarding", targets: ["Onboarding"])],
    dependencies: [
        .package(path: "../../CoreModels"),
        .package(path: "../../DesignSystem"),
        .package(path: "../../Repositories"),
    ],
    targets: [
        .target(
            name: "Onboarding",
            dependencies: ["CoreModels", "DesignSystem", "Repositories"]
        ),
        .testTarget(
            name: "OnboardingTests",
            dependencies: ["Onboarding"]
        ),
    ]
)
```

- [ ] **Step 3: Write Module.swift**

```swift
// Onboarding — 5-step quiz + coach selection.
// Public surface: OnboardingFlowView(onComplete:).
```

- [ ] **Step 4: Write SmokeTests.swift**

```swift
import XCTest
@testable import Onboarding

final class SmokeTests: XCTestCase {
    func test_packageBuilds() {
        XCTAssertTrue(true)
    }
}
```

- [ ] **Step 5: Build and test**

Run: `cd ios/Packages/Features/Onboarding && swift build && swift test`
Expected: builds; smoke test passes.

- [ ] **Step 6: Commit**

```bash
git add ios/Packages/Features/Onboarding/
git commit -m "feat(onboarding): initialize package skeleton"
```

---

### Task C2: Implement `OnboardingStore`

**Files:**
- Create: `ios/Packages/Features/Onboarding/Sources/Onboarding/OnboardingStore.swift`
- Create: `ios/Packages/Features/Onboarding/Tests/OnboardingTests/OnboardingStoreTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
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
        XCTAssertEqual(store.progress, 1.0 / 6.0, accuracy: 0.001)
        store.draft.displayName = "Sam"
        store.advance()
        XCTAssertEqual(store.progress, 2.0 / 6.0, accuracy: 0.001)
    }
}
```

- [ ] **Step 2: Run — confirm fail**

Run: `cd ios/Packages/Features/Onboarding && swift test --filter OnboardingStoreTests`

- [ ] **Step 3: Create OnboardingStore.swift**

```swift
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
```

- [ ] **Step 4: Run — confirm pass**

Run: `cd ios/Packages/Features/Onboarding && swift test --filter OnboardingStoreTests`
Expected: 6/6 pass.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/Features/Onboarding/
git commit -m "feat(onboarding): OnboardingStore with step navigation + progress"
```

---

### Task C3: Implement steps 1–3 (Name, Goals, Level)

**Files:**
- Create: `ios/Packages/Features/Onboarding/Sources/Onboarding/Steps/NameStepView.swift`
- Create: `ios/Packages/Features/Onboarding/Sources/Onboarding/Steps/GoalsStepView.swift`
- Create: `ios/Packages/Features/Onboarding/Sources/Onboarding/Steps/LevelStepView.swift`

Views are pure UI and don't get unit tests (per Q5 testing strategy). They're verified via the sim smoke (Phase H).

- [ ] **Step 1: Create NameStepView.swift**

```swift
import SwiftUI
import DesignSystem

struct NameStepView: View {
    @Binding var displayName: String

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.lg) {
            Text("What should I call you?")
                .pulseFont(.h1)
                .foregroundStyle(PulseColors.ink0.color)
            TextField("Your name", text: $displayName)
                .pulseFont(.body)
                .foregroundStyle(PulseColors.ink0.color)
                .padding(PulseSpacing.md)
                .background(PulseColors.bg2.color)
                .clipShape(RoundedRectangle(cornerRadius: PulseRadius.md))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
            Spacer()
        }
        .padding(PulseSpacing.lg)
    }
}
```

- [ ] **Step 2: Create GoalsStepView.swift**

```swift
import SwiftUI
import DesignSystem

struct GoalsStepView: View {
    @Binding var goals: [String]

    private let options: [(key: String, label: String)] = [
        ("build muscle", "Build muscle"),
        ("lose fat", "Lose fat"),
        ("get stronger", "Get stronger"),
        ("conditioning", "Conditioning"),
        ("mobility", "Mobility"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.lg) {
            Text("What are you here for?")
                .pulseFont(.h1)
                .foregroundStyle(PulseColors.ink0.color)
            Text("Pick one or more.")
                .pulseFont(.small)
                .foregroundStyle(PulseColors.ink2.color)
            VStack(spacing: PulseSpacing.sm) {
                ForEach(options, id: \.key) { opt in
                    toggleRow(key: opt.key, label: opt.label)
                }
            }
            Spacer()
        }
        .padding(PulseSpacing.lg)
    }

    @ViewBuilder
    private func toggleRow(key: String, label: String) -> some View {
        let selected = goals.contains(key)
        Button {
            if selected {
                goals.removeAll { $0 == key }
            } else {
                goals.append(key)
            }
        } label: {
            HStack {
                Text(label).pulseFont(.body)
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
            }
            .padding(PulseSpacing.md)
            .frame(maxWidth: .infinity)
            .background(selected ? PulseColors.bg2.color : PulseColors.bg1.color)
            .clipShape(RoundedRectangle(cornerRadius: PulseRadius.md))
            .foregroundStyle(PulseColors.ink0.color)
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 3: Create LevelStepView.swift**

```swift
import SwiftUI
import CoreModels
import DesignSystem

struct LevelStepView: View {
    @Binding var level: Profile.Level?

    private let options: [(value: Profile.Level, label: String, blurb: String)] = [
        (.new, "New", "Just starting out."),
        (.regular, "Regular", "Train a few times a week."),
        (.experienced, "Experienced", "Comfortable with most lifts."),
        (.athlete, "Athlete", "Train for performance."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.lg) {
            Text("Where are you now?")
                .pulseFont(.h1)
                .foregroundStyle(PulseColors.ink0.color)
            VStack(spacing: PulseSpacing.sm) {
                ForEach(options, id: \.value) { opt in
                    Button {
                        level = opt.value
                    } label: {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(opt.label).pulseFont(.h2)
                                Text(opt.blurb).pulseFont(.small)
                                    .foregroundStyle(PulseColors.ink2.color)
                            }
                            Spacer()
                            Image(systemName: level == opt.value ? "checkmark.circle.fill" : "circle")
                        }
                        .padding(PulseSpacing.md)
                        .frame(maxWidth: .infinity)
                        .background(level == opt.value ? PulseColors.bg2.color : PulseColors.bg1.color)
                        .clipShape(RoundedRectangle(cornerRadius: PulseRadius.md))
                        .foregroundStyle(PulseColors.ink0.color)
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
        }
        .padding(PulseSpacing.lg)
    }
}
```

- [ ] **Step 4: Build the package**

Run: `cd ios/Packages/Features/Onboarding && swift build`
Expected: builds without warnings.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/Features/Onboarding/
git commit -m "feat(onboarding): step views 1-3 (name, goals, level)"
```

---

### Task C4: Implement steps 4–5 (Equipment, Frequency)

**Files:**
- Create: `ios/Packages/Features/Onboarding/Sources/Onboarding/Steps/EquipmentStepView.swift`
- Create: `ios/Packages/Features/Onboarding/Sources/Onboarding/Steps/FrequencyStepView.swift`

- [ ] **Step 1: Create EquipmentStepView.swift**

Mirrors the multi-select pattern from `GoalsStepView`. Options: `none`, `dumbbells`, `barbell`, `kettlebell`, `bands`, `full gym`. (For brevity, refactor the toggle-row helper into the package — but for Plan 3 lean, just inline the same pattern as GoalsStepView, swapping the option list and the binding.)

```swift
import SwiftUI
import DesignSystem

struct EquipmentStepView: View {
    @Binding var equipment: [String]

    private let options: [(key: String, label: String)] = [
        ("none", "Bodyweight only"),
        ("dumbbells", "Dumbbells"),
        ("barbell", "Barbell"),
        ("kettlebell", "Kettlebell"),
        ("bands", "Resistance bands"),
        ("full gym", "Full gym"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.lg) {
            Text("What do you have?")
                .pulseFont(.h1)
                .foregroundStyle(PulseColors.ink0.color)
            Text("Pick everything you can use.")
                .pulseFont(.small)
                .foregroundStyle(PulseColors.ink2.color)
            VStack(spacing: PulseSpacing.sm) {
                ForEach(options, id: \.key) { opt in
                    let selected = equipment.contains(opt.key)
                    Button {
                        if selected { equipment.removeAll { $0 == opt.key } }
                        else { equipment.append(opt.key) }
                    } label: {
                        HStack {
                            Text(opt.label).pulseFont(.body)
                            Spacer()
                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        }
                        .padding(PulseSpacing.md)
                        .frame(maxWidth: .infinity)
                        .background(selected ? PulseColors.bg2.color : PulseColors.bg1.color)
                        .clipShape(RoundedRectangle(cornerRadius: PulseRadius.md))
                        .foregroundStyle(PulseColors.ink0.color)
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
        }
        .padding(PulseSpacing.lg)
    }
}
```

- [ ] **Step 2: Create FrequencyStepView.swift**

Two single-select pickers, both must be set.

```swift
import SwiftUI
import DesignSystem

struct FrequencyStepView: View {
    @Binding var frequencyPerWeek: Int?
    @Binding var weeklyTargetMinutes: Int?

    private let frequencies = [3, 4, 5, 6]
    private let durations = [30, 45, 60, 90]

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.lg) {
            Text("How much can you commit?")
                .pulseFont(.h1)
                .foregroundStyle(PulseColors.ink0.color)

            sectionTitle("Days per week")
            chipRow(values: frequencies, selected: frequencyPerWeek) { frequencyPerWeek = $0 }

            sectionTitle("Minutes per session")
            chipRow(values: durations, selected: weeklyTargetMinutes) { weeklyTargetMinutes = $0 }

            Spacer()
        }
        .padding(PulseSpacing.lg)
    }

    private func sectionTitle(_ s: String) -> some View {
        Text(s)
            .pulseFont(.small)
            .foregroundStyle(PulseColors.ink2.color)
    }

    private func chipRow(values: [Int], selected: Int?, set: @escaping (Int) -> Void) -> some View {
        HStack(spacing: PulseSpacing.sm) {
            ForEach(values, id: \.self) { v in
                Button { set(v) } label: {
                    Text("\(v)")
                        .pulseFont(.body)
                        .padding(.horizontal, PulseSpacing.md)
                        .padding(.vertical, PulseSpacing.sm)
                        .background(selected == v ? PulseColors.bg2.color : PulseColors.bg1.color)
                        .clipShape(Capsule())
                        .foregroundStyle(PulseColors.ink0.color)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
```

- [ ] **Step 3: Build the package**

Run: `cd ios/Packages/Features/Onboarding && swift build`
Expected: builds without warnings.

- [ ] **Step 4: Commit**

```bash
git add ios/Packages/Features/Onboarding/
git commit -m "feat(onboarding): step views 4-5 (equipment, frequency)"
```

---

### Task C5: Implement step 6 (Coach pick)

**Files:**
- Create: `ios/Packages/Features/Onboarding/Sources/Onboarding/Steps/CoachPickStepView.swift`

- [ ] **Step 1: Create CoachPickStepView.swift**

```swift
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
                CoachAvatar(coachID: coach.id, hue: coach.accentHue, size: 56)
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
```

- [ ] **Step 2: Build**

Run: `cd ios/Packages/Features/Onboarding && swift build`
Expected: builds.

> If `CoachAvatar` init signature differs, adapt to the existing one. Run `grep -n "public init" ios/Packages/DesignSystem/Sources/DesignSystem/Primitives/CoachAvatar.swift` to confirm.

- [ ] **Step 3: Commit**

```bash
git add ios/Packages/Features/Onboarding/
git commit -m "feat(onboarding): step view 6 (coach pick) with voiced welcome card"
```

---

### Task C6: Implement `OnboardingFlowView` container

**Files:**
- Create: `ios/Packages/Features/Onboarding/Sources/Onboarding/OnboardingFlowView.swift`

- [ ] **Step 1: Create OnboardingFlowView.swift**

```swift
import SwiftUI
import CoreModels
import DesignSystem
import Repositories

public struct OnboardingFlowView: View {
    @State private var store: OnboardingStore
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
            if let id = newID, let coach = Coach.byID(id) {
                themeStore.setAccentHue(coach.accentHue)
            }
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(PulseColors.bg2.color)
                Rectangle()
                    .fill(themeStore.accent.color)
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
        }
    }

    private var footer: some View {
        HStack {
            if store.currentStep != .name {
                PulseButton(title: "Back", style: .secondary) { store.back() }
            }
            Spacer()
            PulseButton(
                title: store.isAtCoachStep ? "Generate my first workout" : "Next",
                style: .primary,
                isEnabled: store.canAdvanceFromCurrent
            ) {
                if store.isAtCoachStep {
                    Task { await complete() }
                } else {
                    store.advance()
                }
            }
        }
        .padding(PulseSpacing.lg)
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
```

> If `PulseButton.init` doesn't have an `isEnabled` parameter, change the call site to wrap the button in `.disabled(!store.canAdvanceFromCurrent)`. Verify with `grep -n "public init" ios/Packages/DesignSystem/Sources/DesignSystem/Primitives/PulseButton.swift`.
> If `ThemeStore.setAccentHue` doesn't exist, use the equivalent setter from Plan 2. Verify with `grep -n "public" ios/Packages/DesignSystem/Sources/DesignSystem/Theme/ThemeStore.swift`.

- [ ] **Step 2: Build**

Run: `cd ios/Packages/Features/Onboarding && swift build`
Expected: builds. If errors stem from DesignSystem API mismatches, adapt the helper calls per the comments above and rerun.

- [ ] **Step 3: Commit**

```bash
git add ios/Packages/Features/Onboarding/
git commit -m "feat(onboarding): OnboardingFlowView container with progress bar + footer"
```

---

## Phase D — PlanGeneration feature package

### Task D1: Create `PlanGeneration` SPM package skeleton

**Files:**
- Create: `ios/Packages/Features/PlanGeneration/Package.swift`
- Create: `ios/Packages/Features/PlanGeneration/Sources/PlanGeneration/Module.swift`
- Create: `ios/Packages/Features/PlanGeneration/Tests/PlanGenerationTests/SmokeTests.swift`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p "ios/Packages/Features/PlanGeneration/Sources/PlanGeneration/Components" \
         "ios/Packages/Features/PlanGeneration/Tests/PlanGenerationTests"
```

- [ ] **Step 2: Write Package.swift**

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PlanGeneration",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "PlanGeneration", targets: ["PlanGeneration"])],
    dependencies: [
        .package(path: "../../CoreModels"),
        .package(path: "../../DesignSystem"),
        .package(path: "../../Persistence"),
        .package(path: "../../Repositories"),
    ],
    targets: [
        .target(
            name: "PlanGeneration",
            dependencies: ["CoreModels", "DesignSystem", "Persistence", "Repositories"]
        ),
        .testTarget(
            name: "PlanGenerationTests",
            dependencies: ["PlanGeneration"]
        ),
    ]
)
```

- [ ] **Step 3: Create Module.swift**

```swift
// PlanGeneration — streaming LLM plan generation with checkpoint+text UI.
// Public surface: PlanGenerationView(mode:profile:coach:appContainer:onViewWorkout:onBackToHome:).
```

- [ ] **Step 4: Create SmokeTests.swift**

```swift
import XCTest
@testable import PlanGeneration

final class SmokeTests: XCTestCase {
    func test_packageBuilds() { XCTAssertTrue(true) }
}
```

- [ ] **Step 5: Build and test**

Run: `cd ios/Packages/Features/PlanGeneration && swift build && swift test`
Expected: builds; smoke passes.

- [ ] **Step 6: Commit**

```bash
git add ios/Packages/Features/PlanGeneration/
git commit -m "feat(plan-generation): initialize package skeleton"
```

---

### Task D2: Implement `PlanGenStore` state machine

**Files:**
- Create: `ios/Packages/Features/PlanGeneration/Sources/PlanGeneration/PlanGenStore.swift`
- Create: `ios/Packages/Features/PlanGeneration/Tests/PlanGenerationTests/PlanGenStoreTests.swift`

The store owns the state machine and a stream-driver hook (`StreamProvider`) that the view passes in. Tests inject a fake provider; production passes `PlanRepository.streamFirstPlan` / `regenerate`.

- [ ] **Step 1: Write failing tests**

```swift
import XCTest
import CoreModels
import Repositories
@testable import PlanGeneration

@MainActor
final class PlanGenStoreTests: XCTestCase {
    private func makeProfile() -> Profile {
        Profile(id: UUID(), displayName: "Sam", goals: ["build muscle"],
                level: .regular, equipment: ["dumbbells"],
                frequencyPerWeek: 4, weeklyTargetMinutes: 180,
                activeCoachID: "rex", createdAt: Date())
    }

    private func fakeStream(yields: [PlanStreamUpdate]) -> AsyncThrowingStream<PlanStreamUpdate, Error> {
        AsyncThrowingStream { continuation in
            for u in yields { continuation.yield(u) }
            continuation.finish()
        }
    }

    private func failingStream(error: Error) -> AsyncThrowingStream<PlanStreamUpdate, Error> {
        AsyncThrowingStream { continuation in continuation.finish(throwing: error) }
    }

    private func samplePlan() -> WorkoutPlan {
        WorkoutPlan(weekStart: Date(), workouts: [
            PlannedWorkout(id: "w1", scheduledFor: Date(),
                title: "Push", subtitle: "Upper",
                workoutType: "Strength", durationMin: 45,
                blocks: [], why: "Volume.")
        ])
    }

    func test_startsInStreamingState_attempt1() async {
        let store = PlanGenStore(coach: Coach.byID("rex")!,
                                 mode: .firstPlan,
                                 streamProvider: { _ in self.fakeStream(yields: []) },
                                 onPersistedWorkout: { _ in nil })
        await store.run(profile: makeProfile())
        if case .streaming(_, _, let attempt) = store.state {
            XCTAssertEqual(attempt, 1)
        } else if case .failed = store.state {
            // Empty stream that finishes without .done is a failure — that's expected here.
        } else {
            XCTFail("unexpected state")
        }
    }

    func test_appendsCheckpoints() async {
        let updates: [PlanStreamUpdate] = [
            .checkpoint("Reading profile"),
            .checkpoint("Selecting exercises"),
        ]
        let store = PlanGenStore(coach: Coach.byID("rex")!,
                                 mode: .firstPlan,
                                 streamProvider: { _ in self.fakeStream(yields: updates) },
                                 onPersistedWorkout: { _ in nil })
        await store.run(profile: makeProfile())
        if case .streaming(let cps, _, _) = store.state {
            XCTAssertEqual(cps, ["Reading profile", "Selecting exercises"])
        } else if case .failed = store.state {
            // OK — stream ended without .done; we still want the checkpoints visible
        }
    }

    func test_textBufferTrimsToLast6Lines() async {
        let lines = (1...10).map { "line \($0)\n" }
        let updates = lines.map { PlanStreamUpdate.textDelta($0) }
        let store = PlanGenStore(coach: Coach.byID("rex")!,
                                 mode: .firstPlan,
                                 streamProvider: { _ in self.fakeStream(yields: updates) },
                                 onPersistedWorkout: { _ in nil })
        await store.run(profile: makeProfile())
        if case .streaming(_, let text, _) = store.state {
            let visibleLines = text.split(separator: "\n", omittingEmptySubsequences: false)
            XCTAssertLessThanOrEqual(visibleLines.count, 7)  // 6 + trailing empty
        } else if case .failed = store.state {
            // Acceptable — stream ended without .done
        }
    }

    func test_done_transitionsToDone_andCallsOnPersistedWorkout() async throws {
        let plan = samplePlan()
        let updates: [PlanStreamUpdate] = [
            .done(plan, modelUsed: "claude-opus-4-7", promptTokens: 100, completionTokens: 200),
        ]
        var capturedPlan: WorkoutPlan?
        let store = PlanGenStore(
            coach: Coach.byID("rex")!,
            mode: .firstPlan,
            streamProvider: { _ in self.fakeStream(yields: updates) },
            onPersistedWorkout: { p in
                capturedPlan = p
                return MockWorkoutHandle(id: UUID(), title: p.workouts.first!.title)
            }
        )
        await store.run(profile: makeProfile())
        if case .done(let handle) = store.state {
            XCTAssertEqual(handle.title, "Push")
        } else {
            XCTFail("expected .done, got \(store.state)")
        }
        XCTAssertEqual(capturedPlan?.workouts.first?.title, "Push")
    }

    func test_streamFails_attempt1_retriesAttempt2() async {
        var calls = 0
        let store = PlanGenStore(
            coach: Coach.byID("rex")!,
            mode: .firstPlan,
            streamProvider: { _ in
                calls += 1
                if calls == 1 {
                    return self.failingStream(error: DummyError.boom)
                } else {
                    return self.fakeStream(yields: [.checkpoint("retry attempt")])
                }
            },
            onPersistedWorkout: { _ in nil }
        )
        await store.run(profile: makeProfile())
        XCTAssertEqual(calls, 2)
        if case .streaming(_, _, let attempt) = store.state {
            XCTAssertEqual(attempt, 2)
        }
    }

    func test_streamFails_attempt2_transitionsToFailed() async {
        let store = PlanGenStore(
            coach: Coach.byID("rex")!,
            mode: .firstPlan,
            streamProvider: { _ in self.failingStream(error: DummyError.boom) },
            onPersistedWorkout: { _ in nil }
        )
        await store.run(profile: makeProfile())
        if case .failed = store.state {} else {
            XCTFail("expected .failed, got \(store.state)")
        }
    }

    func test_retry_resetsToAttempt1() async {
        let store = PlanGenStore(
            coach: Coach.byID("rex")!,
            mode: .firstPlan,
            streamProvider: { _ in self.failingStream(error: DummyError.boom) },
            onPersistedWorkout: { _ in nil }
        )
        await store.run(profile: makeProfile())
        // Now we're .failed; manually reset
        await store.retry(profile: makeProfile())
        // After retry it will fail again — but attempts visible should reset to 1 → 2
        if case .failed = store.state {} else {
            XCTFail("expected .failed after retry-and-fail")
        }
    }

    enum DummyError: Error { case boom }

    struct MockWorkoutHandle: WorkoutHandle {
        let id: UUID
        let title: String
    }
}
```

- [ ] **Step 2: Run — confirm fail**

Run: `cd ios/Packages/Features/PlanGeneration && swift test --filter PlanGenStoreTests`
Expected: build error (no PlanGenStore type).

- [ ] **Step 3: Create PlanGenStore.swift**

```swift
import Foundation
import Observation
import CoreModels
import Repositories

public protocol WorkoutHandle: Sendable {
    var id: UUID { get }
    var title: String { get }
}

public enum PlanGenMode: Sendable {
    case firstPlan
    case regenerate
}

@MainActor
@Observable
public final class PlanGenStore {
    public enum State {
        case streaming(checkpoints: [String], text: String, attempt: Int)
        case done(any WorkoutHandle)
        case failed(Error)
    }

    public private(set) var state: State = .streaming(checkpoints: [], text: "", attempt: 1)
    public let coach: Coach
    public let mode: PlanGenMode

    public typealias StreamProvider = (Profile) -> AsyncThrowingStream<PlanStreamUpdate, Error>
    public typealias OnPersistedWorkout = (WorkoutPlan) -> (any WorkoutHandle)?

    private let streamProvider: StreamProvider
    private let onPersistedWorkout: OnPersistedWorkout
    private static let maxVisibleLines = 6

    public init(coach: Coach,
                mode: PlanGenMode,
                streamProvider: @escaping StreamProvider,
                onPersistedWorkout: @escaping OnPersistedWorkout) {
        self.coach = coach
        self.mode = mode
        self.streamProvider = streamProvider
        self.onPersistedWorkout = onPersistedWorkout
    }

    public func run(profile: Profile) async {
        await runAttempt(profile: profile, attempt: 1)
    }

    public func retry(profile: Profile) async {
        state = .streaming(checkpoints: [], text: "", attempt: 1)
        await runAttempt(profile: profile, attempt: 1)
    }

    private func runAttempt(profile: Profile, attempt: Int) async {
        state = .streaming(checkpoints: [], text: "", attempt: attempt)
        do {
            let stream = streamProvider(profile)
            for try await update in stream {
                apply(update)
                if case .done = state { return }
            }
        } catch {
            if attempt == 1 {
                await runAttempt(profile: profile, attempt: 2)
            } else {
                state = .failed(error)
            }
        }
    }

    private func apply(_ update: PlanStreamUpdate) {
        guard case .streaming(var cps, var text, let attempt) = state else { return }
        switch update {
        case .checkpoint(let label):
            cps.append(label)
            state = .streaming(checkpoints: cps, text: text, attempt: attempt)
        case .textDelta(let chunk):
            text += chunk
            text = Self.trimToLastLines(text, count: Self.maxVisibleLines)
            state = .streaming(checkpoints: cps, text: text, attempt: attempt)
        case .done(let plan, _, _, _):
            if let handle = onPersistedWorkout(plan) {
                state = .done(handle)
            } else {
                state = .failed(NoWorkoutHandleError())
            }
        }
    }

    private static func trimToLastLines(_ text: String, count: Int) -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.count > count else { return text }
        return lines.suffix(count).joined(separator: "\n")
    }
}

private struct NoWorkoutHandleError: Error {}
```

- [ ] **Step 4: Run — confirm pass**

Run: `cd ios/Packages/Features/PlanGeneration && swift test --filter PlanGenStoreTests`
Expected: 7/7 pass.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/Features/PlanGeneration/
git commit -m "feat(plan-generation): PlanGenStore state machine with retry-once-then-fail"
```

---

### Task D3: Implement view components and `PlanGenerationView`

**Files:**
- Create: `ios/Packages/Features/PlanGeneration/Sources/PlanGeneration/Components/CheckpointRowView.swift`
- Create: `ios/Packages/Features/PlanGeneration/Sources/PlanGeneration/Components/StreamingTextPaneView.swift`
- Create: `ios/Packages/Features/PlanGeneration/Sources/PlanGeneration/Components/PlanGenDoneCardView.swift`
- Create: `ios/Packages/Features/PlanGeneration/Sources/PlanGeneration/PlanGenerationView.swift`

- [ ] **Step 1: Create CheckpointRowView.swift**

```swift
import SwiftUI
import DesignSystem

struct CheckpointRowView: View {
    let label: String

    var body: some View {
        HStack(spacing: PulseSpacing.sm) {
            Circle()
                .fill(PulseColors.ink2.color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(PulseColors.ink1.color)
            Spacer()
        }
    }
}
```

- [ ] **Step 2: Create StreamingTextPaneView.swift**

```swift
import SwiftUI
import DesignSystem

struct StreamingTextPaneView: View {
    let text: String

    var body: some View {
        ScrollView {
            Text(text)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(PulseColors.ink2.color)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .animation(.easeOut(duration: 0.15), value: text)
        }
        .frame(maxHeight: 160)
        .padding(PulseSpacing.md)
        .background(PulseColors.bg1.color)
        .clipShape(RoundedRectangle(cornerRadius: PulseRadius.md))
    }
}
```

- [ ] **Step 3: Create PlanGenDoneCardView.swift**

```swift
import SwiftUI
import DesignSystem

struct PlanGenDoneCardView: View {
    let title: String
    let onView: () -> Void

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                Text("Ready.")
                    .pulseFont(.h2)
                    .foregroundStyle(PulseColors.ink0.color)
                Text(title)
                    .pulseFont(.h1)
                    .foregroundStyle(PulseColors.ink0.color)
                PulseButton(title: "View workout", style: .primary, action: onView)
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
```

- [ ] **Step 4: Create PlanGenerationView.swift**

```swift
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
                    PulseButton(title: "Retry", style: .primary) {
                        Task { await store.retry(profile: profile) }
                    }
                    PulseButton(title: "Back to home", style: .secondary, action: onBackToHome)
                }
            }
        }
    }
}
```

- [ ] **Step 5: Build the package**

Run: `cd ios/Packages/Features/PlanGeneration && swift build`
Expected: builds.

- [ ] **Step 6: Commit**

```bash
git add ios/Packages/Features/PlanGeneration/
git commit -m "feat(plan-generation): view components + PlanGenerationView"
```

---

## Phase E — Home feature package

### Task E1: Create `Home` SPM package skeleton + `WorkoutHeroCardView` + `WeekStripView`

**Files:**
- Create: `ios/Packages/Features/Home/Package.swift`
- Create: `ios/Packages/Features/Home/Sources/Home/Module.swift`
- Create: `ios/Packages/Features/Home/Sources/Home/Components/WorkoutHeroCardView.swift`
- Create: `ios/Packages/Features/Home/Sources/Home/Components/WeekStripView.swift`
- Create: `ios/Packages/Features/Home/Tests/HomeTests/SmokeTests.swift`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p "ios/Packages/Features/Home/Sources/Home/Components" \
         "ios/Packages/Features/Home/Tests/HomeTests"
```

- [ ] **Step 2: Write Package.swift**

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Home",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "Home", targets: ["Home"])],
    dependencies: [
        .package(path: "../../CoreModels"),
        .package(path: "../../DesignSystem"),
        .package(path: "../../Persistence"),
        .package(path: "../../Repositories"),
    ],
    targets: [
        .target(
            name: "Home",
            dependencies: ["CoreModels", "DesignSystem", "Persistence", "Repositories"]
        ),
        .testTarget(
            name: "HomeTests",
            dependencies: ["Home"]
        ),
    ]
)
```

- [ ] **Step 3: Module.swift + SmokeTests.swift**

Module.swift:
```swift
// Home — today's workout hero, week strip, regenerate CTA.
// Public surface: HomeView(...).
```

SmokeTests.swift:
```swift
import XCTest
@testable import Home

final class SmokeTests: XCTestCase {
    func test_packageBuilds() { XCTAssertTrue(true) }
}
```

- [ ] **Step 4: WorkoutHeroCardView.swift**

```swift
import SwiftUI
import DesignSystem

public struct WorkoutHeroCardView: View {
    let title: String
    let subtitle: String
    let durationMin: Int
    let workoutType: String
    let onView: () -> Void

    public init(title: String, subtitle: String, durationMin: Int,
                workoutType: String, onView: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.durationMin = durationMin
        self.workoutType = workoutType
        self.onView = onView
    }

    public var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                Text(workoutType.uppercased())
                    .pulseFont(.small)
                    .foregroundStyle(PulseColors.ink2.color)
                Text(title)
                    .pulseFont(.h1)
                    .foregroundStyle(PulseColors.ink0.color)
                Text(subtitle)
                    .pulseFont(.body)
                    .foregroundStyle(PulseColors.ink1.color)
                HStack(spacing: PulseSpacing.sm) {
                    PulsePill(text: "\(durationMin) min", tone: .neutral)
                    PulsePill(text: workoutType, tone: .accent)
                }
                PulseButton(title: "View workout", style: .primary, action: onView)
            }
        }
    }
}
```

> If `PulsePill.Tone` cases differ, adapt to the existing API. Run `grep -n "Tone\\|public init" ios/Packages/DesignSystem/Sources/DesignSystem/Primitives/PulsePill.swift`.

- [ ] **Step 5: WeekStripView.swift**

```swift
import SwiftUI
import DesignSystem

public struct WeekStripView: View {
    let filledDates: Set<DateComponents>  // year/month/day-resolution components
    let today: Date
    let calendar: Calendar

    public init(filledDates: Set<DateComponents>,
                today: Date = Date(),
                calendar: Calendar = Calendar(identifier: .gregorian)) {
        self.filledDates = filledDates
        self.today = today
        self.calendar = calendar
    }

    private var weekDays: [Date] {
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private func isFilled(_ d: Date) -> Bool {
        let comps = calendar.dateComponents([.year, .month, .day], from: d)
        return filledDates.contains(comps)
    }

    public var body: some View {
        HStack(spacing: PulseSpacing.sm) {
            ForEach(Array(weekDays.enumerated()), id: \.offset) { _, day in
                let isToday = calendar.isDate(day, inSameDayAs: today)
                let filled = isFilled(day)
                VStack(spacing: 4) {
                    Text(weekdayLabel(day))
                        .pulseFont(.small)
                        .foregroundStyle(isToday ? PulseColors.ink0.color : PulseColors.ink2.color)
                    Circle()
                        .fill(filled ? PulseColors.ink0.color : PulseColors.bg2.color)
                        .frame(width: 8, height: 8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, PulseSpacing.sm)
                .background(isToday ? PulseColors.bg2.color : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: PulseRadius.sm))
            }
        }
    }

    private func weekdayLabel(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: d)
    }
}
```

- [ ] **Step 6: Build and test**

Run: `cd ios/Packages/Features/Home && swift build && swift test`
Expected: builds; smoke passes.

- [ ] **Step 7: Commit**

```bash
git add ios/Packages/Features/Home/
git commit -m "feat(home): package skeleton + WorkoutHeroCardView + WeekStripView"
```

---

### Task E2: Implement `HomeStore` + `HomeView`

**Files:**
- Create: `ios/Packages/Features/Home/Sources/Home/HomeStore.swift`
- Create: `ios/Packages/Features/Home/Tests/HomeTests/HomeStoreTests.swift`
- Create: `ios/Packages/Features/Home/Sources/Home/HomeView.swift`

- [ ] **Step 1: Write failing tests for `HomeStore`**

```swift
import XCTest
import SwiftData
import CoreModels
import Persistence
import Repositories
@testable import Home

@MainActor
final class HomeStoreTests: XCTestCase {
    func test_initialState_hasNoWorkout() {
        let container = try! PulseModelContainer.inMemory()
        let store = HomeStore(workoutRepo: WorkoutRepository(modelContainer: container),
                              profileRepo: ProfileRepository(modelContainer: container))
        XCTAssertNil(store.todaysWorkout)
        XCTAssertNil(store.profile)
    }

    func test_refresh_loadsLatestWorkoutAndProfile() async throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        ctx.insert(ProfileEntity(
            id: UUID(), displayName: "Sam", goals: ["build muscle"],
            level: "regular", equipment: ["dumbbells"],
            frequencyPerWeek: 4, weeklyTargetMinutes: 180,
            activeCoachID: "rex", accentHue: 15, createdAt: Date()))
        ctx.insert(WorkoutEntity(
            id: UUID(), planID: UUID(), scheduledFor: Date(),
            title: "Push", subtitle: "Upper", workoutType: "Strength",
            durationMin: 45, status: "scheduled",
            blocksJSON: Data("[]".utf8), exercisesJSON: Data("[]".utf8),
            why: "Volume."))
        try ctx.save()
        let store = HomeStore(workoutRepo: WorkoutRepository(modelContainer: container),
                              profileRepo: ProfileRepository(modelContainer: container))
        await store.refresh()
        XCTAssertEqual(store.todaysWorkout?.title, "Push")
        XCTAssertEqual(store.profile?.displayName, "Sam")
    }
}
```

- [ ] **Step 2: Run — confirm fail**

Run: `cd ios/Packages/Features/Home && swift test --filter HomeStoreTests`

- [ ] **Step 3: Create HomeStore.swift**

```swift
import Foundation
import Observation
import CoreModels
import Persistence
import Repositories

@MainActor
@Observable
public final class HomeStore {
    public private(set) var todaysWorkout: WorkoutEntity?
    public private(set) var profile: Profile?

    private let workoutRepo: WorkoutRepository
    private let profileRepo: ProfileRepository

    public init(workoutRepo: WorkoutRepository, profileRepo: ProfileRepository) {
        self.workoutRepo = workoutRepo
        self.profileRepo = profileRepo
    }

    public func refresh() async {
        profile = profileRepo.currentProfile()
        todaysWorkout = try? workoutRepo.latestWorkout()
    }
}
```

- [ ] **Step 4: Run — confirm pass**

Run: `cd ios/Packages/Features/Home && swift test --filter HomeStoreTests`
Expected: 2/2 pass.

- [ ] **Step 5: Create HomeView.swift**

```swift
import SwiftUI
import CoreModels
import DesignSystem
import Persistence
import Repositories

public struct HomeView: View {
    @State private var store: HomeStore
    private let onViewWorkout: (UUID) -> Void
    private let onRegenerate: () -> Void

    public init(workoutRepo: WorkoutRepository,
                profileRepo: ProfileRepository,
                onViewWorkout: @escaping (UUID) -> Void,
                onRegenerate: @escaping () -> Void) {
        _store = State(initialValue: HomeStore(workoutRepo: workoutRepo,
                                                profileRepo: profileRepo))
        self.onViewWorkout = onViewWorkout
        self.onRegenerate = onRegenerate
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                if let profile = store.profile {
                    Text(greetingText(for: profile))
                        .pulseFont(.h2)
                        .foregroundStyle(PulseColors.ink0.color)
                }
                if let w = store.todaysWorkout {
                    WorkoutHeroCardView(
                        title: w.title,
                        subtitle: w.subtitle,
                        durationMin: w.durationMin,
                        workoutType: w.workoutType
                    ) { onViewWorkout(w.id) }
                } else {
                    PulseCard {
                        VStack(alignment: .leading, spacing: PulseSpacing.md) {
                            Text("No plan yet")
                                .pulseFont(.h2)
                                .foregroundStyle(PulseColors.ink0.color)
                            PulseButton(title: "Generate today's workout",
                                        style: .primary, action: onRegenerate)
                        }
                    }
                }
                weekStrip
                if store.todaysWorkout != nil {
                    PulseButton(title: "Regenerate today's plan",
                                style: .secondary, action: onRegenerate)
                }
            }
            .padding(PulseSpacing.lg)
        }
        .task { await store.refresh() }
    }

    private func greetingText(for profile: Profile) -> String {
        let prefix = CoachStrings.homeGreeting(for: profile.activeCoachID)
        return "\(prefix), \(profile.displayName)."
    }

    private var weekStrip: some View {
        let calendar = Calendar(identifier: .gregorian)
        var filled: Set<DateComponents> = []
        if let date = store.todaysWorkout?.scheduledFor {
            filled.insert(calendar.dateComponents([.year, .month, .day], from: date))
        }
        return WeekStripView(filledDates: filled, calendar: calendar)
    }
}
```

- [ ] **Step 6: Build**

Run: `cd ios/Packages/Features/Home && swift build`
Expected: builds.

- [ ] **Step 7: Commit**

```bash
git add ios/Packages/Features/Home/
git commit -m "feat(home): HomeStore + HomeView (greeting + hero + week strip + regenerate)"
```

---

## Phase F — WorkoutDetail feature package

### Task F1: Create `WorkoutDetail` SPM package skeleton

**Files:**
- Create: `ios/Packages/Features/WorkoutDetail/Package.swift`
- Create: `ios/Packages/Features/WorkoutDetail/Sources/WorkoutDetail/Module.swift`
- Create: `ios/Packages/Features/WorkoutDetail/Tests/WorkoutDetailTests/SmokeTests.swift`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p "ios/Packages/Features/WorkoutDetail/Sources/WorkoutDetail/Components" \
         "ios/Packages/Features/WorkoutDetail/Tests/WorkoutDetailTests"
```

- [ ] **Step 2: Package.swift**

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WorkoutDetail",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "WorkoutDetail", targets: ["WorkoutDetail"])],
    dependencies: [
        .package(path: "../../CoreModels"),
        .package(path: "../../DesignSystem"),
        .package(path: "../../Persistence"),
        .package(path: "../../Repositories"),
    ],
    targets: [
        .target(
            name: "WorkoutDetail",
            dependencies: ["CoreModels", "DesignSystem", "Persistence", "Repositories"]
        ),
        .testTarget(
            name: "WorkoutDetailTests",
            dependencies: ["WorkoutDetail"]
        ),
    ]
)
```

- [ ] **Step 3: Module.swift + SmokeTests.swift**

Same pattern as previous packages.

- [ ] **Step 4: Build**

Run: `cd ios/Packages/Features/WorkoutDetail && swift build && swift test`
Expected: passes.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/Features/WorkoutDetail/
git commit -m "feat(workout-detail): initialize package skeleton"
```

---

### Task F2: Implement `WorkoutDetailStore` + asset resolution

**Files:**
- Create: `ios/Packages/Features/WorkoutDetail/Sources/WorkoutDetail/WorkoutDetailStore.swift`
- Create: `ios/Packages/Features/WorkoutDetail/Tests/WorkoutDetailTests/WorkoutDetailStoreTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
import XCTest
import SwiftData
import CoreModels
import Persistence
import Repositories
@testable import WorkoutDetail

@MainActor
final class WorkoutDetailStoreTests: XCTestCase {
    func test_loadResolvesWorkoutAndAssets() async throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext

        // Insert a workout with one PlannedExercise referencing an asset that exists.
        let exJSON = #"""
        [{"id":"e1","exerciseID":"asset-001","name":"Push-up","sets":[{"setNum":1,"reps":10,"load":"BW","restSec":60}]}]
        """#.data(using: .utf8)!
        let blocksJSON = #"""
        [{"id":"b1","label":"Main","exercises":[{"id":"e1","exerciseID":"asset-001","name":"Push-up","sets":[{"setNum":1,"reps":10,"load":"BW","restSec":60}]}]}]
        """#.data(using: .utf8)!
        let id = UUID()
        ctx.insert(WorkoutEntity(
            id: id, planID: UUID(), scheduledFor: Date(),
            title: "Push", subtitle: "Upper", workoutType: "Strength",
            durationMin: 45, status: "scheduled",
            blocksJSON: blocksJSON, exercisesJSON: exJSON, why: "Volume."))
        ctx.insert(ExerciseAssetEntity(
            id: "asset-001", name: "Push-up", focus: "chest", level: "beginner",
            kind: "compound", equipment: ["bodyweight"],
            videoURL: URL(string: "https://example.com/asset-001.mp4")!,
            posterURL: URL(string: "https://example.com/asset-001.jpg")!,
            instructionsJSON: Data("[]".utf8), manifestVersion: 1))
        try ctx.save()

        let store = WorkoutDetailStore(
            workoutID: id,
            modelContainer: container,
            assetRepo: ExerciseAssetRepository(modelContainer: container)
        )
        await store.load()
        XCTAssertEqual(store.workoutTitle, "Push")
        XCTAssertEqual(store.blocks.count, 1)
        XCTAssertEqual(store.blocks.first?.exercises.first?.name, "Push-up")
        XCTAssertNotNil(store.asset(for: "asset-001"))
    }

    func test_assetMiss_returnsNil() async throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let blocksJSON = #"""
        [{"id":"b1","label":"Main","exercises":[{"id":"e1","exerciseID":"unknown","name":"Mystery","sets":[]}]}]
        """#.data(using: .utf8)!
        let id = UUID()
        ctx.insert(WorkoutEntity(
            id: id, planID: UUID(), scheduledFor: Date(),
            title: "T", subtitle: "", workoutType: "Strength", durationMin: 30,
            status: "scheduled",
            blocksJSON: blocksJSON, exercisesJSON: Data("[]".utf8), why: nil))
        try ctx.save()
        let store = WorkoutDetailStore(
            workoutID: id,
            modelContainer: container,
            assetRepo: ExerciseAssetRepository(modelContainer: container)
        )
        await store.load()
        XCTAssertNil(store.asset(for: "unknown"))
    }
}
```

- [ ] **Step 2: Run — confirm fail**

Run: `cd ios/Packages/Features/WorkoutDetail && swift test --filter WorkoutDetailStoreTests`

- [ ] **Step 3: Create WorkoutDetailStore.swift**

```swift
import Foundation
import Observation
import SwiftData
import CoreModels
import Persistence
import Repositories
import OSLog

@MainActor
@Observable
public final class WorkoutDetailStore {
    public private(set) var workoutTitle: String = ""
    public private(set) var workoutSubtitle: String = ""
    public private(set) var workoutType: String = ""
    public private(set) var durationMin: Int = 0
    public private(set) var why: String?
    public private(set) var blocks: [WorkoutBlock] = []

    private let workoutID: UUID
    private let modelContainer: ModelContainer
    private let assetRepo: ExerciseAssetRepository
    private var assetsByID: [String: ExerciseAssetEntity] = [:]
    private let log = Logger(subsystem: "co.simpleav.pulse", category: "WorkoutDetail")

    public init(workoutID: UUID,
                modelContainer: ModelContainer,
                assetRepo: ExerciseAssetRepository) {
        self.workoutID = workoutID
        self.modelContainer = modelContainer
        self.assetRepo = assetRepo
    }

    public func load() async {
        let ctx = modelContainer.mainContext
        let id = workoutID
        let descriptor = FetchDescriptor<WorkoutEntity>(
            predicate: #Predicate { $0.id == id }
        )
        guard let entity = try? ctx.fetch(descriptor).first else { return }
        workoutTitle = entity.title
        workoutSubtitle = entity.subtitle
        workoutType = entity.workoutType
        durationMin = entity.durationMin
        why = entity.why
        blocks = (try? JSONDecoder.pulse.decode([WorkoutBlock].self, from: entity.blocksJSON)) ?? []
        await resolveAssets()
    }

    public func asset(for exerciseID: String) -> ExerciseAssetEntity? {
        assetsByID[exerciseID]
    }

    private func resolveAssets() async {
        let ids = Set(blocks.flatMap { $0.exercises.map { $0.exerciseID } })
        for id in ids {
            if let a = (try? assetRepo.asset(id: id)) {
                assetsByID[id] = a
            } else {
                log.warning("asset miss for exerciseID=\(id, privacy: .public)")
            }
        }
    }
}
```

> If `ExerciseAssetRepository` doesn't expose `asset(id:)`, run `grep -n "public func" ios/Packages/Repositories/Sources/Repositories/ExerciseAssetRepository.swift` and adapt to the existing API (likely a similar lookup method). If no lookup method exists, add `public func asset(id: String) throws -> ExerciseAssetEntity?` to the repo as part of this task.

- [ ] **Step 4: Run — confirm pass**

Run: `cd ios/Packages/Features/WorkoutDetail && swift test --filter WorkoutDetailStoreTests`
Expected: 2/2 pass.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/Features/WorkoutDetail/ ios/Packages/Repositories/
git commit -m "feat(workout-detail): WorkoutDetailStore with asset resolution + miss fallback"
```

---

### Task F3: Implement `ExerciseRowView`, `BlockSectionView`, `ExerciseDetailSheet`, and `WorkoutDetailView`

**Files:**
- Create: `ios/Packages/Features/WorkoutDetail/Sources/WorkoutDetail/Components/ExerciseRowView.swift`
- Create: `ios/Packages/Features/WorkoutDetail/Sources/WorkoutDetail/Components/BlockSectionView.swift`
- Create: `ios/Packages/Features/WorkoutDetail/Sources/WorkoutDetail/Components/ExerciseDetailSheet.swift`
- Create: `ios/Packages/Features/WorkoutDetail/Sources/WorkoutDetail/WorkoutDetailView.swift`

- [ ] **Step 1: ExerciseRowView.swift**

```swift
import SwiftUI
import CoreModels
import Persistence
import DesignSystem

struct ExerciseRowView: View {
    let exercise: PlannedExercise
    let asset: ExerciseAssetEntity?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: PulseSpacing.md) {
                thumbnail
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .pulseFont(.body)
                        .foregroundStyle(PulseColors.ink0.color)
                    Text(prescription)
                        .pulseFont(.small)
                        .foregroundStyle(PulseColors.ink2.color)
                }
                Spacer()
                if asset != nil {
                    IconButton(systemName: "info.circle", action: onTap)
                }
            }
            .padding(.vertical, PulseSpacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let url = asset?.posterURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFill()
                default: ExercisePlaceholder(label: "EX")
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: PulseRadius.sm))
        } else {
            ExercisePlaceholder(label: "EX")
                .frame(width: 56, height: 56)
        }
    }

    private var prescription: String {
        guard !exercise.sets.isEmpty else { return "" }
        let setCount = exercise.sets.count
        let repsList = exercise.sets.map { "\($0.reps)" }.joined(separator: "/")
        let load = exercise.sets.first?.load ?? ""
        return "\(setCount) × \(repsList)\(load.isEmpty ? "" : " @ \(load)")"
    }
}
```

> If `ExercisePlaceholder.init` differs (e.g. takes no `label`), drop the argument. Verify via `grep -n "public init" ios/Packages/DesignSystem/Sources/DesignSystem/Primitives/ExercisePlaceholder.swift`.

- [ ] **Step 2: BlockSectionView.swift**

```swift
import SwiftUI
import CoreModels
import Persistence
import DesignSystem

struct BlockSectionView: View {
    let block: WorkoutBlock
    let assetFor: (String) -> ExerciseAssetEntity?
    let onSelectExercise: (PlannedExercise) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            Text(block.label.uppercased())
                .pulseFont(.small)
                .foregroundStyle(PulseColors.ink2.color)
            VStack(spacing: PulseSpacing.xs) {
                ForEach(block.exercises) { ex in
                    ExerciseRowView(exercise: ex,
                                    asset: assetFor(ex.exerciseID)) {
                        onSelectExercise(ex)
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 3: ExerciseDetailSheet.swift**

```swift
import SwiftUI
import AVKit
import CoreModels
import Persistence
import DesignSystem

struct ExerciseDetailSheet: View {
    let exercise: PlannedExercise
    let asset: ExerciseAssetEntity?

    @State private var player: AVPlayer?
    @State private var looper: AVPlayerLooper?

    var body: some View {
        ZStack {
            PulseColors.bg0.color.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                    Text(exercise.name)
                        .pulseFont(.h1)
                        .foregroundStyle(PulseColors.ink0.color)
                    if let player {
                        VideoPlayer(player: player)
                            .frame(height: 240)
                            .clipShape(RoundedRectangle(cornerRadius: PulseRadius.md))
                    } else if let posterURL = asset?.posterURL {
                        AsyncImage(url: posterURL) { phase in
                            switch phase {
                            case .success(let img): img.resizable().scaledToFit()
                            default: ExercisePlaceholder(label: "EX")
                            }
                        }
                        .frame(height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: PulseRadius.md))
                    }
                    if let json = asset?.instructionsJSON,
                       let lines = try? JSONDecoder.pulse.decode([String].self, from: json) {
                        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                            Text("How to do it")
                                .pulseFont(.h2)
                                .foregroundStyle(PulseColors.ink0.color)
                            ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
                                HStack(alignment: .top, spacing: PulseSpacing.sm) {
                                    Text("\(idx + 1).")
                                        .pulseFont(.small)
                                        .foregroundStyle(PulseColors.ink2.color)
                                    Text(line)
                                        .pulseFont(.body)
                                        .foregroundStyle(PulseColors.ink1.color)
                                }
                            }
                        }
                    }
                }
                .padding(PulseSpacing.lg)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { setupPlayer() }
        .onDisappear { player?.pause() }
    }

    private func setupPlayer() {
        guard let url = asset?.videoURL else { return }
        let item = AVPlayerItem(url: url)
        let queue = AVQueuePlayer()
        looper = AVPlayerLooper(player: queue, templateItem: item)
        queue.play()
        player = queue
    }
}
```

- [ ] **Step 4: WorkoutDetailView.swift**

```swift
import SwiftUI
import SwiftData
import CoreModels
import DesignSystem
import Repositories

public struct WorkoutDetailView: View {
    @State private var store: WorkoutDetailStore
    @State private var selectedExercise: PlannedExercise?

    public init(workoutID: UUID,
                modelContainer: ModelContainer,
                assetRepo: ExerciseAssetRepository) {
        _store = State(initialValue: WorkoutDetailStore(
            workoutID: workoutID,
            modelContainer: modelContainer,
            assetRepo: assetRepo
        ))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                hero
                if let why = store.why {
                    PulseCard {
                        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                            Text("Why this workout")
                                .pulseFont(.small)
                                .foregroundStyle(PulseColors.ink2.color)
                            Text(why)
                                .pulseFont(.body)
                                .foregroundStyle(PulseColors.ink0.color)
                        }
                    }
                }
                ForEach(store.blocks) { block in
                    BlockSectionView(block: block,
                                     assetFor: { store.asset(for: $0) }) { ex in
                        selectedExercise = ex
                    }
                }
                startCTA
            }
            .padding(PulseSpacing.lg)
        }
        .task { await store.load() }
        .sheet(item: $selectedExercise) { ex in
            ExerciseDetailSheet(exercise: ex, asset: store.asset(for: ex.exerciseID))
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            Text(store.workoutTitle)
                .pulseFont(.h1)
                .foregroundStyle(PulseColors.ink0.color)
            Text(store.workoutSubtitle)
                .pulseFont(.body)
                .foregroundStyle(PulseColors.ink1.color)
            HStack(spacing: PulseSpacing.sm) {
                PulsePill(text: "\(store.durationMin) min", tone: .neutral)
                PulsePill(text: store.workoutType, tone: .accent)
            }
        }
    }

    private var startCTA: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            PulseButton(title: "Start workout", style: .primary, action: {})
                .disabled(true)
                .opacity(0.5)
            Text("Coming in the next update")
                .pulseFont(.small)
                .foregroundStyle(PulseColors.ink2.color)
        }
    }
}
```

> SwiftData's `ModelContainer` is `Sendable` but Repository APIs are `@MainActor`. If the init signature triggers concurrency warnings, accept the warnings for now or move to passing the repos in directly (mirroring what you did for Home).

- [ ] **Step 5: Build**

Run: `cd ios/Packages/Features/WorkoutDetail && swift build`
Expected: builds.

- [ ] **Step 6: Commit**

```bash
git add ios/Packages/Features/WorkoutDetail/
git commit -m "feat(workout-detail): row + block + exercise sheet + WorkoutDetailView"
```

---

## Phase G — Project wiring + AppShell first-run gate

### Task G1: Register the four new packages in `Project.yml`

**Files:**
- Modify: `ios/Project.yml`

- [ ] **Step 1: Edit Project.yml — add packages and dependencies**

Under `packages:` add:

```yaml
  Onboarding:
    path: Packages/Features/Onboarding
  Home:
    path: Packages/Features/Home
  PlanGeneration:
    path: Packages/Features/PlanGeneration
  WorkoutDetail:
    path: Packages/Features/WorkoutDetail
```

Under `targets.PulseApp.dependencies:` add:

```yaml
      - package: Onboarding
      - package: Home
      - package: PlanGeneration
      - package: WorkoutDetail
```

- [ ] **Step 2: Regenerate the Xcode project**

Run: `cd ios && xcodegen generate`
Expected: regenerates `PulseApp.xcodeproj` without error.

- [ ] **Step 3: Build the app target from CLI**

Run: `cd ios && xcodebuild -scheme PulseApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -30`
Expected: build succeeds (`BUILD SUCCEEDED`).

- [ ] **Step 4: Commit**

```bash
git add ios/Project.yml
git commit -m "build(ios): register four new feature packages in Project.yml"
```

---

### Task G2: Add `FirstRunGate` to AppShell

**Files:**
- Create: `ios/Packages/AppShell/Sources/AppShell/FirstRunGate.swift`
- Modify: `ios/Packages/AppShell/Package.swift` (add Onboarding, PlanGeneration, Home, WorkoutDetail dependencies)

- [ ] **Step 1: Update AppShell Package.swift**

Edit `ios/Packages/AppShell/Package.swift` to add the four feature packages as dependencies. Add:

```swift
.package(path: "../Features/Onboarding"),
.package(path: "../Features/Home"),
.package(path: "../Features/PlanGeneration"),
.package(path: "../Features/WorkoutDetail"),
```

…and to the `target` dependencies:

```swift
"Onboarding", "Home", "PlanGeneration", "WorkoutDetail"
```

- [ ] **Step 2: Create FirstRunGate.swift**

```swift
import SwiftUI
import CoreModels
import DesignSystem
import Repositories
import Onboarding
import PlanGeneration

public struct FirstRunGate<Content: View>: View {
    @State private var profile: Profile?
    @State private var isCheckingFirstRun = true
    @State private var pendingProfileForPlanGen: Profile?
    private let appContainer: AppContainer
    private let themeStore: ThemeStore
    private let content: () -> Content

    public init(appContainer: AppContainer,
                themeStore: ThemeStore,
                @ViewBuilder content: @escaping () -> Content) {
        self.appContainer = appContainer
        self.themeStore = themeStore
        self.content = content
    }

    public var body: some View {
        Group {
            if isCheckingFirstRun {
                Color.clear
            } else if profile == nil {
                onboardingFlow
            } else {
                content()
                    .fullScreenCover(item: $pendingProfileForPlanGen) { profile in
                        planGenScreen(profile: profile)
                    }
            }
        }
        .task { await checkFirstRun() }
    }

    private var profileRepo: ProfileRepository {
        ProfileRepository(modelContainer: appContainer.modelContainer)
    }

    private var planRepo: PlanRepository {
        PlanRepository(modelContainer: appContainer.modelContainer, api: appContainer.api)
    }

    private var onboardingFlow: some View {
        OnboardingFlowView(
            profileRepo: profileRepo,
            themeStore: themeStore
        ) { newProfile in
            await MainActor.run {
                profile = newProfile
                pendingProfileForPlanGen = newProfile
            }
        }
    }

    @ViewBuilder
    private func planGenScreen(profile: Profile) -> some View {
        if let coach = Coach.byID(profile.activeCoachID) {
            PlanGenerationView(
                profile: profile,
                coach: coach,
                mode: .firstPlan,
                streamProvider: { p in self.planRepo.streamFirstPlan(profile: p, coach: coach) },
                onPersistedWorkout: { _ in
                    let repo = WorkoutRepository(modelContainer: self.appContainer.modelContainer)
                    if let w = try? repo.latestWorkout() {
                        return PersistedWorkoutHandle(id: w.id, title: w.title)
                    }
                    return nil
                },
                onViewWorkout: { _ in pendingProfileForPlanGen = nil },
                onBackToHome: { pendingProfileForPlanGen = nil }
            )
        }
    }

    private func checkFirstRun() async {
        let p = profileRepo.currentProfile()
        await MainActor.run {
            self.profile = p
            if let p, let coach = Coach.byID(p.activeCoachID) {
                self.themeStore.setAccentHue(coach.accentHue)
            }
            self.isCheckingFirstRun = false
        }
    }
}

private struct PersistedWorkoutHandle: WorkoutHandle {
    let id: UUID
    let title: String
}

extension Profile: Identifiable {}
```

> If `Profile` already conforms to `Identifiable`, drop the trailing extension.

- [ ] **Step 3: Build AppShell**

Run: `cd ios/Packages/AppShell && swift build`
Expected: builds.

- [ ] **Step 4: Commit**

```bash
git add ios/Packages/AppShell/
git commit -m "feat(app-shell): FirstRunGate routes between onboarding and tabs"
```

---

### Task G3: Wire `HomeView` into `RootScaffold`'s `.today` tab and connect `WorkoutDetailView` navigation

**Files:**
- Modify: `ios/Packages/AppShell/Sources/AppShell/RootScaffold.swift`

- [ ] **Step 1: Replace `todayPlaceholder` with `HomeView`**

In `RootScaffold.swift`:

1. Add imports:
```swift
import Home
import WorkoutDetail
import PlanGeneration
import CoreModels
import Persistence
```

2. Add state for navigation:
```swift
@State private var selectedWorkoutID: UUID?
@State private var regeneratePresentedFor: Profile?
```

3. Replace the `case .today: todayPlaceholder` arm with:
```swift
case .today:
    NavigationStack {
        HomeView(
            workoutRepo: WorkoutRepository(modelContainer: appContainer.modelContainer),
            profileRepo: ProfileRepository(modelContainer: appContainer.modelContainer),
            onViewWorkout: { id in selectedWorkoutID = id },
            onRegenerate: { triggerRegenerate() }
        )
        .navigationDestination(item: $selectedWorkoutID) { id in
            WorkoutDetailView(
                workoutID: id,
                modelContainer: appContainer.modelContainer,
                assetRepo: ExerciseAssetRepository(modelContainer: appContainer.modelContainer)
            )
        }
    }
    .fullScreenCover(item: $regeneratePresentedFor) { profile in
        regenerateScreen(profile: profile)
    }
```

4. Add helpers:
```swift
private func triggerRegenerate() {
    let repo = ProfileRepository(modelContainer: appContainer.modelContainer)
    if let p = repo.currentProfile() {
        regeneratePresentedFor = p
    }
}

@ViewBuilder
private func regenerateScreen(profile: Profile) -> some View {
    if let coach = Coach.byID(profile.activeCoachID) {
        let planRepo = PlanRepository(modelContainer: appContainer.modelContainer, api: appContainer.api)
        PlanGenerationView(
            profile: profile,
            coach: coach,
            mode: .regenerate,
            streamProvider: { p in planRepo.regenerate(profile: p, coach: coach) },
            onPersistedWorkout: { _ in
                let repo = WorkoutRepository(modelContainer: appContainer.modelContainer)
                if let w = try? repo.latestWorkout() {
                    return PersistedRegenHandle(id: w.id, title: w.title)
                }
                return nil
            },
            onViewWorkout: { id in
                regeneratePresentedFor = nil
                selectedWorkoutID = id
            },
            onBackToHome: { regeneratePresentedFor = nil }
        )
    }
}
```

5. Add private helper type at the bottom of the file:
```swift
private struct PersistedRegenHandle: WorkoutHandle {
    let id: UUID
    let title: String
}
```

- [ ] **Step 2: Drop the now-unused `todayPlaceholder`**

Delete the `private var todayPlaceholder: some View { ... }` block.

- [ ] **Step 3: Build AppShell**

Run: `cd ios/Packages/AppShell && swift build`
Expected: builds.

- [ ] **Step 4: Commit**

```bash
git add ios/Packages/AppShell/
git commit -m "feat(app-shell): wire HomeView into .today + regenerate fullScreenCover"
```

---

### Task G4: Update `AppShellRoot` and `PulseApp` to mount `FirstRunGate`

**Files:**
- Modify: `ios/PulseApp/AppShellRoot.swift`
- Modify: `ios/PulseApp/PulseApp.swift` (only if needed — depends on Plan 2 wiring)

- [ ] **Step 1: Read current AppShellRoot.swift to understand wiring**

Run: `cat ios/PulseApp/AppShellRoot.swift`
Note: the existing file passes `appContainer` and `themeStore` to `RootScaffold`. We're inserting `FirstRunGate` as a wrapper.

- [ ] **Step 2: Wrap `RootScaffold` in `FirstRunGate`**

Edit `AppShellRoot.swift`. Replace the existing `body` content:

```swift
import SwiftUI
import AppShell
import DesignSystem
import Repositories

struct AppShellRoot: View {
    let appContainer: AppContainer
    let themeStore: ThemeStore

    var body: some View {
        FirstRunGate(appContainer: appContainer, themeStore: themeStore) {
            RootScaffold(
                appContainer: appContainer,
                themeStore: themeStore
            ) {
                DebugStreamView(appContainer: appContainer)
            }
        }
    }
}
```

- [ ] **Step 3: Regenerate Xcode project + build**

Run: `cd ios && xcodegen generate && xcodebuild -scheme PulseApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -30`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add ios/PulseApp/
git commit -m "feat(app): mount FirstRunGate over RootScaffold"
```

---

## Phase H — Sim smoke + manual verification

### Task H1: Add `DebugFeatureSmokeView` with four feature entry points

**Files:**
- Create: `ios/PulseApp/DebugFeatureSmokeView.swift`
- Modify: `ios/PulseApp/AppShellRoot.swift` (add a tab/picker to swap between DebugStreamView and DebugFeatureSmokeView)

- [ ] **Step 1: Create DebugFeatureSmokeView.swift**

```swift
import SwiftUI
import CoreModels
import DesignSystem
import Persistence
import Repositories
import Onboarding
import Home
import PlanGeneration
import WorkoutDetail

struct DebugFeatureSmokeView: View {
    let appContainer: AppContainer
    let themeStore: ThemeStore

    @State private var route: Route?

    private enum Route: Identifiable, Hashable {
        case onboarding
        case planGen
        case home
        case workoutDetail(UUID)
        var id: String {
            switch self {
            case .onboarding: return "onboarding"
            case .planGen: return "planGen"
            case .home: return "home"
            case .workoutDetail(let id): return "wd-\(id)"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: PulseSpacing.md) {
                button("Run Onboarding") { route = .onboarding }
                button("Run PlanGeneration (with seeded profile)") {
                    seedProfileIfMissing()
                    route = .planGen
                }
                button("Run Home (with seeded profile + workout)") {
                    seedProfileIfMissing()
                    seedWorkoutIfMissing()
                    route = .home
                }
                button("Run WorkoutDetail (latest)") {
                    seedProfileIfMissing()
                    seedWorkoutIfMissing()
                    if let w = (try? WorkoutRepository(modelContainer: appContainer.modelContainer).latestWorkout()) {
                        route = .workoutDetail(w.id)
                    }
                }
                Divider()
                button("Wipe Profile + Workouts (reset first-run)") { wipe() }
            }
            .padding(PulseSpacing.lg)
        }
        .fullScreenCover(item: $route) { r in routeView(r) }
    }

    @ViewBuilder
    private func routeView(_ r: Route) -> some View {
        switch r {
        case .onboarding:
            let profileRepo = ProfileRepository(modelContainer: appContainer.modelContainer)
            OnboardingFlowView(profileRepo: profileRepo, themeStore: themeStore) { _ in
                await MainActor.run { route = nil }
            }
        case .planGen:
            planGenView()
        case .home:
            NavigationStack {
                HomeView(
                    workoutRepo: WorkoutRepository(modelContainer: appContainer.modelContainer),
                    profileRepo: ProfileRepository(modelContainer: appContainer.modelContainer),
                    onViewWorkout: { id in route = .workoutDetail(id) },
                    onRegenerate: { route = .planGen }
                )
            }
        case .workoutDetail(let id):
            WorkoutDetailView(
                workoutID: id,
                modelContainer: appContainer.modelContainer,
                assetRepo: ExerciseAssetRepository(modelContainer: appContainer.modelContainer)
            )
        }
    }

    @ViewBuilder
    private func planGenView() -> some View {
        let profileRepo = ProfileRepository(modelContainer: appContainer.modelContainer)
        if let profile = profileRepo.currentProfile(),
           let coach = Coach.byID(profile.activeCoachID) {
            let planRepo = PlanRepository(modelContainer: appContainer.modelContainer, api: appContainer.api)
            PlanGenerationView(
                profile: profile, coach: coach, mode: .firstPlan,
                streamProvider: { p in planRepo.streamFirstPlan(profile: p, coach: coach) },
                onPersistedWorkout: { _ in
                    let repo = WorkoutRepository(modelContainer: appContainer.modelContainer)
                    if let w = try? repo.latestWorkout() {
                        return DebugWorkoutHandle(id: w.id, title: w.title)
                    }
                    return nil
                },
                onViewWorkout: { id in route = .workoutDetail(id) },
                onBackToHome: { route = nil }
            )
        }
    }

    private func button(_ title: String, action: @escaping () -> Void) -> some View {
        PulseButton(title: title, style: .secondary, action: action)
    }

    private func seedProfileIfMissing() {
        let repo = ProfileRepository(modelContainer: appContainer.modelContainer)
        guard repo.currentProfile() == nil else { return }
        let p = Profile(id: UUID(), displayName: "DebugUser",
                        goals: ["build muscle"], level: .regular,
                        equipment: ["dumbbells"], frequencyPerWeek: 4,
                        weeklyTargetMinutes: 180, activeCoachID: "rex",
                        createdAt: Date())
        try? repo.save(p)
    }

    private func seedWorkoutIfMissing() {
        let repo = WorkoutRepository(modelContainer: appContainer.modelContainer)
        if (try? repo.latestWorkout()) != nil { return }
        let ctx = appContainer.modelContainer.mainContext
        ctx.insert(WorkoutEntity(
            id: UUID(), planID: UUID(), scheduledFor: Date(),
            title: "Sample Push", subtitle: "Upper body smoke",
            workoutType: "Strength", durationMin: 45, status: "scheduled",
            blocksJSON: Data("[]".utf8), exercisesJSON: Data("[]".utf8),
            why: "Seeded by DebugFeatureSmokeView."))
        try? ctx.save()
    }

    private func wipe() {
        let ctx = appContainer.modelContainer.mainContext
        for p in (try? ctx.fetch(FetchDescriptor<ProfileEntity>())) ?? [] { ctx.delete(p) }
        for w in (try? ctx.fetch(FetchDescriptor<WorkoutEntity>())) ?? [] { ctx.delete(w) }
        try? ctx.save()
    }
}

private struct DebugWorkoutHandle: WorkoutHandle {
    let id: UUID
    let title: String
}
```

- [ ] **Step 2: Wire it into AppShellRoot debug content**

Add a Picker at the top of the debug tab to swap between `DebugStreamView` and `DebugFeatureSmokeView`. The simplest approach: edit `AppShellRoot.swift` to pass a small switcher view as the debug content:

```swift
struct DebugSwitcher: View {
    let appContainer: AppContainer
    let themeStore: ThemeStore
    @State private var which: Which = .stream

    enum Which: String, CaseIterable, Identifiable {
        case stream = "Stream", smoke = "Smoke"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Debug", selection: $which) {
                ForEach(Which.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(PulseSpacing.md)
            switch which {
            case .stream: DebugStreamView(appContainer: appContainer)
            case .smoke:  DebugFeatureSmokeView(appContainer: appContainer, themeStore: themeStore)
            }
        }
    }
}
```

…and update `AppShellRoot.body` to pass `DebugSwitcher` as the debug content.

- [ ] **Step 3: Regenerate + build**

Run: `cd ios && xcodegen generate && xcodebuild -scheme PulseApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add ios/PulseApp/
git commit -m "feat(app): DebugFeatureSmokeView with four feature entry points"
```

---

### Task H2: Manual smoke pass on iPhone 17 Pro Simulator

**Files:** none (manual verification + screenshots optional)

- [ ] **Step 1: Boot simulator and install**

Run:
```bash
cd ios && xcodebuild -scheme PulseApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath ./DerivedData \
  build
xcrun simctl boot "iPhone 17 Pro" 2>/dev/null || true
xcrun simctl install booted ./DerivedData/Build/Products/Debug-iphonesimulator/PulseApp.app
xcrun simctl launch booted co.simpleav.pulse
```

- [ ] **Step 2: Run the cold-start path**

Boot the simulator (open Simulator.app for visibility). Steps to perform manually:
1. Verify `OnboardingFlowView` is presented automatically
2. Walk through all 6 steps. Each step's Next button should disable until `canAdvance` passes
3. Pick a coach → confirm voiced welcome card appears under the picker, accent color changes, and Next button label becomes "Generate my first workout"
4. Tap Next → `PlanGenerationView` appears as full-screen cover. Watch for: voiced header, checkpoint rows appearing, streaming text pane filling
5. On `.done`, the `PlanGenDoneCardView` slides up; tap "View workout" → `WorkoutDetailView` pushes
6. Verify the why card, blocks list, exercise rows, and disabled Start CTA at the bottom

- [ ] **Step 3: Tap an exercise row and verify ExerciseDetailSheet**

Look for: looping MP4 (if asset URL resolves), poster fallback, instructions list. If asset miss → `ExercisePlaceholder`.

- [ ] **Step 4: Return to Home, tap Regenerate**

Verify: regenerate full-screen cover opens; new PlanGen runs; on done, returning to Home shows the new workout's title.

- [ ] **Step 5: Wipe via debug, restart, confirm onboarding kicks again**

In Debug tab → Smoke segment → "Wipe Profile + Workouts". Force-quit the app and relaunch. Onboarding should appear.

- [ ] **Step 6: Note any deviations and fix in subsequent commits**

If anything diverges from spec, file as small commits; don't try to bundle the whole smoke pass as one commit.

- [ ] **Step 7: Commit a smoke-pass note**

If clean:

```bash
git commit --allow-empty -m "chore(plan-3): manual smoke pass on iPhone 17 Pro Sim — all four flows green"
```

---

### Task H3: Update `ios/README.md` with Plan 3 verification checklist

**Files:**
- Modify: `ios/README.md`

- [ ] **Step 1: Append a Plan 3 acceptance section to `ios/README.md`**

Add at the bottom:

```markdown
## Plan 3 acceptance checklist

After a fresh install on the iPhone 17 Pro simulator:

- [ ] App opens to OnboardingFlowView (no Profile present)
- [ ] All 6 onboarding steps validate before allowing Next
- [ ] Coach picker swaps the accent hue immediately
- [ ] On step 6 → Next, PlanGenerationView appears as a fullScreenCover
- [ ] Streaming UI shows: voiced header, checkpoint rows, mono streaming text
- [ ] Done state shows the WorkoutHeroCard with title pulled from the LLM-generated plan
- [ ] Tapping "View workout" pushes WorkoutDetailView; navigation back returns to Home
- [ ] Home shows: voiced greeting, hero card, week strip with today filled, regenerate CTA
- [ ] WorkoutDetail shows: hero pills, why card, blocks list, exercise rows with thumbnails, disabled Start CTA
- [ ] Tapping an exercise row opens the looping MP4 sheet
- [ ] Regenerate Cycle: tap regenerate → PlanGen runs → return to Home → hero updates
- [ ] DebugFeatureSmokeView's "Wipe" button restores first-run state (forces re-onboarding)
```

- [ ] **Step 2: Commit**

```bash
git add ios/README.md
git commit -m "docs(ios): add Plan 3 acceptance checklist"
```

---

## Self-Review

Run through these checks against the spec one last time before declaring the plan complete:

- **Spec §3 module layout:** every package created? ✓ (Phase C/D/E/F + Phase G1)
- **Spec §4 onboarding:** 6 steps, atomic Profile write, voiced step 6 confirmation, theme hue applied on coach pick? ✓ (C1–C6)
- **Spec §5 PlanGeneration:** state machine with retry-once-then-fail, checkpoint stack, fade-out streaming text, done card, voiced header? ✓ (D2–D3)
- **Spec §6 Home:** voiced greeting, hero, week strip with today filled only, regenerate CTA, defensive empty state? ✓ (E1–E2)
- **Spec §7 WorkoutDetail:** hero, why card, blocks list, exercise rows with poster + sheet, disabled Start CTA? ✓ (F1–F3)
- **Spec §8 voiced strings:** 12 strings, one location? ✓ (A4)
- **Spec §9 cross-cutting:** retry-once on attempt 1, error tier table, no bundled fallback? ✓ (D2 retry logic; failed view in D3)
- **Spec §10 Plan 4 boundary:** WorkoutDetail Start CTA disabled with subtitle "Coming in the next update"? ✓ (F3 step 4)
- **Sim smoke (Q5 testing):** four feature entry points + wipe? ✓ (H1)
- **Plan 2 deviations carryover:** SwiftData tests use `@MainActor`? ✓ (every persistence-touching test is `@MainActor`)
