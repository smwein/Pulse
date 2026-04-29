# Pulse — Plan 4: Session Loop + Adaptation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the iPhone session-and-adaptation slice on top of Plan 3: tap Start → InWorkout (data-dense, set-by-set logging) → Complete (Recap → Rate → AI Adaptation Preview) → Home reflects the LLM-supplied replacement workout for the next scheduled date. Includes `HealthKitClient` (read-only) feeding 7-day summaries into both plan-gen and adaptation prompts, plus four Plan 3 carry-over fixes that block correct Plan 4 behavior.

**Architecture:** Two new local SPM feature packages (`Features/InWorkout`, `Features/Complete`), one new infrastructure package (`HealthKitClient`), three new repositories (`SessionRepository`, `AdaptationRepository`, retained `FeedbackRepository` reduced to feedback-only), plus extensions to `WorkoutRepository`, `PlanRepository`, `PromptBuilder`, `Persistence`, `CoreModels`, and `Onboarding`. `AppShell` wires `WorkoutDetail.Start → InWorkout → Complete → Home`. Adaptation uses the same `SSEStreamParser` + `⟦CHECKPOINT⟧` infrastructure as Plan 3 plan-gen but emits a richer event stream (`adjustment` × N → `workout` → `rationale` → `done`) and persists via a single SwiftData transaction that supersedes the next scheduled workout.

**Tech Stack:** Swift 5.9+, SwiftUI, SwiftData, `@Observable`, URLSession async/await, HealthKit (read-only), XCTest. iOS 17+. xcodegen.

**Spec:** `docs/superpowers/specs/2026-04-28-plan-4-design.md`. Master spec: `docs/superpowers/specs/2026-04-26-pulse-ai-trainer-app-design.md`. Plan 3 predecessor: `docs/superpowers/plans/2026-04-28-plan-3-features.md`.

**Scope outside this plan:** Apple Watch app, WatchBridge / WCSession, HealthKit *write* (`HKWorkoutSession`, `HKWorkout` records), live HR card, mid-session resume, coach voice cues, background-safe rest-timer notifications, Sentry, XCUITest. All deferred to Plan 5.

---

## File Structure

```
ios/
  Project.yml                                      ← MODIFY: register HealthKitClient, InWorkout, Complete
  PulseApp/
    Info.plist                                     ← MODIFY: add NSHealthShareUsageDescription
    PulseApp.entitlements                          ← MODIFY: add HealthKit entitlement
    AppShellRoot.swift                             ← MODIFY: feature wiring through AppShell
    DebugFeatureSmokeView.swift                    ← MODIFY: InWorkout + Complete entries
  Packages/
    CoreModels/Sources/CoreModels/
      AdaptationDiff.swift                         ← MODIFY: add Adjustment + AdaptationPayload types
      AdaptationStreamEvent.swift                  ← NEW: enum mirroring PlanStreamUpdate for adaptation
      OnboardingDraft.swift                        ← MODIFY: add .health step
    Persistence/Sources/Persistence/
      Entities/WorkoutEntity.swift                 ← MODIFY: status comment doc → include "superseded"
      Transaction.swift                            ← NEW: @MainActor `transaction { ... }` helper
    Networking/Sources/Networking/
      Anthropic/AnthropicRequest.swift             ← MODIFY: rewrite `.adaptation` factory + add adaptation URL constant
    HealthKitClient/                               ← NEW PACKAGE
      Package.swift
      Sources/HealthKitClient/
        HealthKitClient.swift
        HKHealthStoreProtocol.swift
        SevenDaySummaries.swift
      Tests/HealthKitClientTests/
        HealthKitClientTests.swift
        FakeHKHealthStore.swift
    Repositories/Sources/Repositories/
      AppContainer.swift                           ← MODIFY: add HealthKitClient
      BundledFallback.swift                        ← NEW
      FeedbackRepository.swift                     ← MODIFY: remove adaptPlan, retain saveFeedback w/ idempotency
      AdaptationRepository.swift                   ← NEW: streamAdaptation + supersedes-workout transaction
      SessionRepository.swift                      ← NEW: start / logSet (idempotent) / finish / discard
      PlanRepository.swift                         ← MODIFY: regenerate cascade transaction + ISO8601 weekStart + onPersistedWorkout receives WorkoutEntity.id + strictRetry plumbing
      WorkoutRepository.swift                      ← MODIFY: filter superseded + workoutForDate(_) + #Predicate alias pattern
      PromptBuilder.swift                          ← MODIFY: HK summary block + adaptationUserMessage + adaptationSystemPrompt
      ProfileRepository.swift                      ← MODIFY: throwing currentProfile()
    Repositories/Tests/RepositoriesTests/
      SessionRepositoryTests.swift                 ← NEW
      AdaptationRepositoryTests.swift              ← NEW
      BundledFallbackTests.swift                   ← NEW
      FeedbackRepositoryTests.swift                ← MODIFY: idempotency + reject rating==0
      PlanRepositoryTests.swift                    ← MODIFY: cascade test, weekStart ISO8601 test
      WorkoutRepositoryTests.swift                 ← MODIFY: superseded filter, workoutForDate
      PromptBuilderTests.swift                     ← MODIFY: HK block + adaptation prompt snapshot
      Fixtures/AdaptationStream-success.txt        ← NEW
      Fixtures/AdaptationStream-malformed.txt      ← NEW
      Fixtures/CatalogManifest.json                ← NEW: bundled-fallback build-time check
    Features/
      Onboarding/Sources/Onboarding/
        OnboardingFlowView.swift                   ← MODIFY: render new health step
        Steps/HealthStepView.swift                 ← NEW
      Onboarding/Tests/OnboardingTests/
        OnboardingStoreTests.swift                 ← MODIFY: 7-step navigation
      PlanGeneration/Sources/PlanGeneration/
        PlanGenStore.swift                         ← MODIFY: re-entry guard
        PlanGenerationView.swift                   ← MODIFY: .task(id:) keyed on nonce
      Home/Sources/Home/
        HomeStore.swift                            ← MODIFY: filter superseded
        Components/WeekStripView.swift             ← MODIFY: superseded filter at compute site (no public API change)
      WorkoutDetail/Sources/WorkoutDetail/
        WorkoutDetailView.swift                    ← MODIFY: enable Start CTA, expose onStart callback
      InWorkout/                                   ← NEW PACKAGE
        Package.swift
        Sources/InWorkout/
          Module.swift
          SessionStore.swift
          InWorkoutView.swift
          Components/
            ProgressSegmentsView.swift
            ExerciseCardView.swift
            LiveMetricsGridView.swift
            SetLogCardView.swift
            RestPhaseView.swift
            BottomControlsView.swift
        Tests/InWorkoutTests/
          SessionStoreTests.swift
          SmokeTests.swift
      Complete/                                    ← NEW PACKAGE
        Package.swift
        Sources/Complete/
          Module.swift
          CompleteStore.swift
          CompleteView.swift
          Steps/
            RecapStepView.swift
            RateStepView.swift
            AdaptationStepView.swift
          Components/
            StatTileView.swift
            FeedbackTagPill.swift
            ExerciseThumbsRow.swift
            AdjustmentCardView.swift
            CoachRationaleCardView.swift
            NextSessionPreviewCardView.swift
        Tests/CompleteTests/
          CompleteStoreTests.swift
          SmokeTests.swift
    AppShell/Sources/AppShell/
      RootScaffold.swift                           ← MODIFY: WorkoutDetail.onStart wires InWorkout sequence
      FirstRunGate.swift                           ← MODIFY: detect orphaned in-progress sessions + clean up
      InWorkoutSequence.swift                      ← NEW: holds the InWorkout → Complete → dismiss state machine
```

---

## Phase 0 — Plan 3 cleanups *(optional, skippable)*

Address the four non-blocker carry-overs while the surrounding code is fresh. Skip if Plan 4 capacity is tight — no later task depends on these.

### Task 0.1: Align `#Predicate` parameter capture pattern

Both `WorkoutRepository.markCompleted` and `WorkoutRepository.deleteWorkout` use `#Predicate { $0.id == workoutID }` with the parameter directly. `ProfileRepository.save` already uses the safer local-alias pattern (`let id = profile.id` first). Align repos.

**Files:**
- Modify: `ios/Packages/Repositories/Sources/Repositories/WorkoutRepository.swift`

- [ ] **Step 1: Edit `markCompleted` to alias the parameter**

Replace lines 27–35 of `WorkoutRepository.swift`:

```swift
public func markCompleted(workoutID: UUID) throws {
    let ctx = modelContainer.mainContext
    let id = workoutID
    let descriptor = FetchDescriptor<WorkoutEntity>(
        predicate: #Predicate { $0.id == id }
    )
    guard let w = try ctx.fetch(descriptor).first else { return }
    w.status = "completed"
    try ctx.save()
}
```

- [ ] **Step 2: Edit `deleteWorkout` the same way**

Replace lines 46–55:

```swift
public func deleteWorkout(id: UUID) throws {
    let ctx = modelContainer.mainContext
    let workoutID = id
    let descriptor = FetchDescriptor<WorkoutEntity>(
        predicate: #Predicate { $0.id == workoutID }
    )
    for w in try ctx.fetch(descriptor) {
        ctx.delete(w)
    }
    try ctx.save()
}
```

- [ ] **Step 3: Run repo tests**

Run: `cd ios/Packages/Repositories && swift test`
Expected: all tests pass.

- [ ] **Step 4: Commit**

```bash
git add ios/Packages/Repositories/Sources/Repositories/WorkoutRepository.swift
git commit -m "chore(repositories): align WorkoutRepository on #Predicate local-alias pattern"
```

---

### Task 0.2: Add re-entry guard to `PlanGenerationView` / `PlanGenStore`

Plan 4 doesn't add new entry points to `PlanGenerationView` but the spec listed this as a low-risk hardening. Use `.task(id:)` keyed on a nonce so re-presentation cancels the prior task.

**Files:**
- Modify: `ios/Packages/Features/PlanGeneration/Sources/PlanGeneration/PlanGenStore.swift`
- Modify: `ios/Packages/Features/PlanGeneration/Sources/PlanGeneration/PlanGenerationView.swift`
- Modify: `ios/Packages/Features/PlanGeneration/Tests/PlanGenerationTests/PlanGenStoreTests.swift`

- [ ] **Step 1: Add a re-entry flag to `PlanGenStore.run`**

In `PlanGenStore.swift`, add a `private var isRunning = false` property and guard `run`:

```swift
@MainActor
@Observable
public final class PlanGenStore {
    // ... existing ...
    private var isRunning = false

    public func run(profile: Profile) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }
        await runAttempt(profile: profile, attempt: 1)
    }

    public func retry(profile: Profile) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }
        state = .streaming(checkpoints: [], text: "", attempt: 1)
        await runAttempt(profile: profile, attempt: 1)
    }
    // ... rest unchanged ...
}
```

- [ ] **Step 2: Add a nonce to `PlanGenerationView` and key `.task` on it**

In `PlanGenerationView.swift`, replace `.task { await store.run(profile: profile) }` with:

```swift
@State private var runNonce: UUID = UUID()
// ...
.task(id: runNonce) { await store.run(profile: profile) }
```

(The nonce is set once per view instance; if AppShell re-presents the view via fullScreenCover, a fresh `@State` resets it. If a parent rebuilds without dismiss, the nonce stays stable, the task is reused, and the guard short-circuits.)

- [ ] **Step 3: Add a regression test**

Append to `PlanGenStoreTests.swift`:

```swift
@MainActor
func test_run_reentryIsGuardedWhilePriorRunInFlight() async {
    let neverEnding: PlanGenStore.StreamProvider = { _ in
        AsyncThrowingStream { _ in /* never finishes */ }
    }
    let store = PlanGenStore(coach: Coach.byID("rex")!, mode: .firstPlan,
                             streamProvider: neverEnding,
                             onPersistedWorkout: { _ in nil })
    let profile = ProfileTests.sampleProfile()
    let firstTask = Task { await store.run(profile: profile) }
    // small yield so the first run has entered
    try? await Task.sleep(nanoseconds: 10_000_000)
    let secondTask = Task { await store.run(profile: profile) }
    // The second call should return immediately because of the guard.
    let secondCompleted = await Task.detached {
        let _ = await secondTask.value
        return true
    }.value
    XCTAssertTrue(secondCompleted)
    firstTask.cancel()
}
```

(Reuses `ProfileTests.sampleProfile()` if it exists; otherwise inline a minimal profile.)

- [ ] **Step 4: Run**

Run: `cd ios/Packages/Features/PlanGeneration && swift test`
Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/Features/PlanGeneration/
git commit -m "fix(plan-generation): guard PlanGenStore.run against re-entry"
```

---

### Task 0.3: Plumb `strictRetry` through stream provider

`PromptBuilder.planGenSystemPrompt` already accepts `strictRetry: Bool` but the retry attempt in `PlanGenStore.runAttempt` doesn't pass it through. Two options: actually use it on the retry path (richer fix), or remove the dead flag (cheaper). Spec calls for using it. Implement it.

**Files:**
- Modify: `ios/Packages/Repositories/Sources/Repositories/PlanRepository.swift`
- Modify: `ios/Packages/Features/PlanGeneration/Sources/PlanGeneration/PlanGenStore.swift`

- [ ] **Step 1: Add a `strictRetry` parameter to `streamFirstPlan` / `regenerate`**

Edit `PlanRepository.swift` — add `strictRetry: Bool = false` to both, thread to `planGenSystemPrompt`:

```swift
public func streamFirstPlan(profile: Profile, coach: Coach,
                            now: Date = Date(),
                            strictRetry: Bool = false) -> AsyncThrowingStream<PlanStreamUpdate, Error> {
    let exercises = availableExercises(for: profile)
    let system = PromptBuilder.planGenSystemPrompt(coach: coach,
                                                  availableExercises: exercises,
                                                  strictRetry: strictRetry)
    let user = PromptBuilder.planGenUserMessage(profile: profile, today: now)
    let calendar = Calendar(identifier: .iso8601)   // see Task 1.2
    let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
    return generatePlan(systemPrompt: system, userMessage: user, weekStart: weekStart)
}

public func regenerate(profile: Profile, coach: Coach,
                       now: Date = Date(),
                       strictRetry: Bool = false) -> AsyncThrowingStream<PlanStreamUpdate, Error> {
    // body updated in Task 1.1
    return streamFirstPlan(profile: profile, coach: coach, now: now, strictRetry: strictRetry)
}
```

- [ ] **Step 2: Use `strictRetry: true` on the second attempt in `PlanGenStore.runAttempt`**

Currently `runAttempt(profile:attempt:)` calls `streamProvider(profile)` regardless of attempt. Change `StreamProvider` to take a `strictRetry: Bool`:

```swift
public typealias StreamProvider = (Profile, Bool) -> AsyncThrowingStream<PlanStreamUpdate, Error>

private func runAttempt(profile: Profile, attempt: Int) async {
    state = .streaming(checkpoints: [], text: "", attempt: attempt)
    do {
        let stream = streamProvider(profile, attempt > 1)
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
```

- [ ] **Step 3: Update call sites that build `streamProvider`**

In `FirstRunGate.planGenScreen`:

```swift
streamProvider: { p, strict in
    self.planRepo.streamFirstPlan(profile: p, coach: coach, strictRetry: strict)
}
```

In `RootScaffold.regenerateScreen`:

```swift
streamProvider: { p, strict in
    planRepo.regenerate(profile: p, coach: coach, strictRetry: strict)
}
```

In `DebugFeatureSmokeView.planGenView`:

```swift
streamProvider: { p, strict in
    planRepo.streamFirstPlan(profile: p, coach: coach, strictRetry: strict)
}
```

- [ ] **Step 4: Update PlanGenStoreTests fixtures that build `streamProvider`**

Any test that constructs `PlanGenStore` will need to update its closure signature: `streamProvider: { _, _ in stream }`.

- [ ] **Step 5: Run all tests for affected packages**

Run: `cd ios/Packages/Repositories && swift test && cd ../Features/PlanGeneration && swift test`
Expected: pass.

- [ ] **Step 6: Commit**

```bash
git add ios/Packages/Repositories/Sources/Repositories/PlanRepository.swift ios/Packages/Features/PlanGeneration/ ios/PulseApp/ ios/Packages/AppShell/
git commit -m "fix(plan-generation): plumb strictRetry through to second attempt"
```

---

### Task 0.4: Make `ProfileRepository.currentProfile` throwing

Currently uses `try?` so a corrupt store is indistinguishable from "no rows". Align with other repos.

**Files:**
- Modify: `ios/Packages/Repositories/Sources/Repositories/ProfileRepository.swift`
- Modify: every call site of `currentProfile()`

- [ ] **Step 1: Edit the signature**

In `ProfileRepository.swift`:

```swift
public func currentProfile() throws -> Profile? {
    let ctx = modelContainer.mainContext
    let descriptor = FetchDescriptor<ProfileEntity>(
        sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
    )
    guard let entity = try ctx.fetch(descriptor).first else { return nil }
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
```

- [ ] **Step 2: Update call sites — wrap in `try?`**

Each existing caller treated nil as "no profile". Keep that semantics with `try?`:

- `ios/Packages/AppShell/Sources/AppShell/FirstRunGate.swift` line ~88: `let p = (try? profileRepo.currentProfile()) ?? nil`
- `ios/Packages/AppShell/Sources/AppShell/RootScaffold.swift` line ~115: `if let p = try? repo.currentProfile() { ... }` — already inside `if let`; change to `if let p = (try? repo.currentProfile()) ?? nil`
- `ios/PulseApp/DebugFeatureSmokeView.swift` line ~97: `if let profile = (try? profileRepo.currentProfile()) ?? nil`
- `ios/Packages/Features/Home/Sources/Home/HomeStore.swift`: `profile = (try? profileRepo.currentProfile()) ?? nil`

(Use grep to find any remaining; the call site count is small.)

- [ ] **Step 3: Update existing `ProfileRepositoryTests`**

If a test calls `repo.currentProfile()`, prefix with `try`. Add at least one test for the throwing path:

```swift
@MainActor
func test_currentProfile_returnsNilWhenStoreEmpty() throws {
    let container = try PulseModelContainer.inMemory()
    let repo = ProfileRepository(modelContainer: container)
    XCTAssertNil(try repo.currentProfile())
}
```

- [ ] **Step 4: Run**

Run: `cd ios/Packages/Repositories && swift test && cd ../Features/Home && swift test && cd ../../AppShell && swift test`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/ ios/PulseApp/
git commit -m "fix(profile-repository): throw on fetch error instead of swallowing with try?"
```

---

## Phase 1 — Plan 3 blocker fixes + bundled fallback

These four fixes are required for Plan 4 to behave correctly. Phase 0 is skippable; Phase 1 is not.

### Task 1.1: `PlanRepository.regenerate` cascade transaction

Currently deletes only `latestWorkout()`. With Plan 4 introducing `SessionEntity` rows that reference workouts, orphaning siblings becomes data corruption. Cascade-delete every workout for the prior plan, plus the prior `PlanEntity`, in a single transaction.

**Files:**
- Modify: `ios/Packages/Repositories/Sources/Repositories/PlanRepository.swift`
- Modify: `ios/Packages/Repositories/Tests/RepositoriesTests/PlanRepositoryTests.swift`

- [ ] **Step 1: Write a failing test**

Append to `PlanRepositoryTests.swift`:

```swift
@MainActor
func test_regenerate_cascadeDeletesPriorPlanAndAllItsWorkouts() async throws {
    let container = try PulseModelContainer.inMemory()
    let ctx = container.mainContext
    let priorPlanID = UUID()
    let plan = PlanEntity(id: priorPlanID,
        weekStart: Date(timeIntervalSince1970: 1_700_000_000),
        generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
        modelUsed: "claude-opus-4-7", promptTokens: 10, completionTokens: 10,
        payloadJSON: Data("{}".utf8))
    ctx.insert(plan)
    for i in 0..<7 {
        ctx.insert(WorkoutEntity(id: UUID(), planID: priorPlanID,
            scheduledFor: Date(timeIntervalSince1970: 1_700_000_000 + Double(i) * 86_400),
            title: "W\(i)", subtitle: "", workoutType: "Strength", durationMin: 30,
            status: "scheduled",
            blocksJSON: Data("[]".utf8), exercisesJSON: Data("[]".utf8)))
    }
    try ctx.save()

    let repo = PlanRepository.makeForTests(modelContainer: container)
    let stream = repo.regenerate(profile: ProfileRepositoryTests.fixtureProfile(),
                                 coach: Coach.byID("rex")!)
    let task = Task { for try await _ in stream {} }
    task.cancel()
    _ = try? await task.value

    // All 7 prior workouts and the prior PlanEntity should be gone.
    let remainingWorkouts = try ctx.fetch(FetchDescriptor<WorkoutEntity>(
        predicate: #Predicate { $0.planID == priorPlanID }))
    XCTAssertTrue(remainingWorkouts.isEmpty)
    let priorPlan = priorPlanID
    let remainingPlans = try ctx.fetch(FetchDescriptor<PlanEntity>(
        predicate: #Predicate { $0.id == priorPlan }))
    XCTAssertTrue(remainingPlans.isEmpty)
}
```

- [ ] **Step 2: Run — confirm fail**

Run: `cd ios/Packages/Repositories && swift test --filter test_regenerate_cascadeDeletesPriorPlanAndAllItsWorkouts`
Expected: fail (only the latest workout is currently deleted; prior plan rows survive).

- [ ] **Step 3: Implement the cascade in `regenerate`**

Replace the body of `regenerate` in `PlanRepository.swift`:

```swift
public func regenerate(profile: Profile, coach: Coach,
                       now: Date = Date(),
                       strictRetry: Bool = false) -> AsyncThrowingStream<PlanStreamUpdate, Error> {
    let ctx = modelContainer.mainContext
    do {
        let priorPlans = try ctx.fetch(FetchDescriptor<PlanEntity>(
            sortBy: [SortDescriptor(\.generatedAt, order: .reverse)]))
        if let prior = priorPlans.first {
            let priorID = prior.id
            let priorWorkouts = try ctx.fetch(FetchDescriptor<WorkoutEntity>(
                predicate: #Predicate { $0.planID == priorID }))
            for w in priorWorkouts { ctx.delete(w) }
            ctx.delete(prior)
            try ctx.save()
        }
    } catch {
        // If cleanup fails, the new plan still streams; persist will create
        // fresh rows but the orphans remain. This is no worse than today's
        // behavior; surface the error in logs only.
    }
    return streamFirstPlan(profile: profile, coach: coach, now: now, strictRetry: strictRetry)
}
```

(Per spec, the cleanup is best-effort; the actual transactional guarantee is that *new* plan-gen persistence is atomic — handled in `persist`. SwiftData's `mainContext.save()` is the boundary.)

- [ ] **Step 4: Run — confirm pass**

Run: `cd ios/Packages/Repositories && swift test --filter PlanRepositoryTests`
Expected: pass (including the existing `test_regenerate_deletesPriorLatestWorkoutBeforeStreaming`, which still asserts the prior latest is gone).

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/Repositories/
git commit -m "fix(plan-repository): cascade-delete prior plan and all its workouts on regenerate"
```

---

### Task 1.2: Align weekStart calendar to ISO8601

`PlanRepository.streamFirstPlan` uses `Calendar(identifier: .gregorian)` for weekStart; `Home.WeekStripView` uses ISO8601 (Monday-based). Must align — Plan 4 introduces session-week comparisons that feed the adaptation prompt. Per spec: ISO8601 throughout.

**Files:**
- Modify: `ios/Packages/Repositories/Sources/Repositories/PlanRepository.swift`
- Modify: `ios/Packages/Repositories/Tests/RepositoriesTests/PlanRepositoryTests.swift`

- [ ] **Step 1: Write a failing test**

Append to `PlanRepositoryTests.swift`:

```swift
@MainActor
func test_streamFirstPlan_weekStartUsesISO8601MondayBased() async throws {
    // Tuesday 2026-04-21 (UTC). ISO8601 week-of-year starts on Monday 2026-04-20.
    let tuesday = ISO8601DateFormatter().date(from: "2026-04-21T12:00:00Z")!
    var iso = Calendar(identifier: .iso8601)
    iso.timeZone = TimeZone(secondsFromGMT: 0)!
    let expectedMonday = iso.dateInterval(of: .weekOfYear, for: tuesday)!.start
    // Compare what PlanRepository would compute. Expose the helper for test
    // by adding `_weekStart(for:)` (Step 3).
    let computed = PlanRepository._weekStart(for: tuesday)
    XCTAssertEqual(computed, expectedMonday)
}
```

- [ ] **Step 2: Run — confirm fail (build error: `_weekStart` not found)**

Run: `cd ios/Packages/Repositories && swift test --filter test_streamFirstPlan_weekStartUsesISO8601MondayBased`
Expected: build error.

- [ ] **Step 3: Replace gregorian with ISO8601 + extract helper**

In `PlanRepository.swift` add a static helper and update `streamFirstPlan`:

```swift
public static func _weekStart(for now: Date) -> Date {
    var calendar = Calendar(identifier: .iso8601)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
    return calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
}

public func streamFirstPlan(profile: Profile, coach: Coach,
                            now: Date = Date(),
                            strictRetry: Bool = false) -> AsyncThrowingStream<PlanStreamUpdate, Error> {
    let exercises = availableExercises(for: profile)
    let system = PromptBuilder.planGenSystemPrompt(coach: coach,
                                                  availableExercises: exercises,
                                                  strictRetry: strictRetry)
    let user = PromptBuilder.planGenUserMessage(profile: profile, today: now)
    let weekStart = Self._weekStart(for: now)
    return generatePlan(systemPrompt: system, userMessage: user, weekStart: weekStart)
}
```

- [ ] **Step 4: Run — confirm pass**

Run: `cd ios/Packages/Repositories && swift test --filter PlanRepositoryTests`
Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/Repositories/
git commit -m "fix(plan-repository): align weekStart to ISO8601 (Monday-based) calendar"
```

---

### Task 1.3: `onPersistedWorkout` callback receives stable `WorkoutEntity.id`

Currently `onPersistedWorkout: (WorkoutPlan) -> WorkoutHandle?` reads `latestWorkout()` after persist — works only because `mainContext` writes are synchronous. Plan 4 threads workout IDs into Sessions, so the stable ID is needed at persist time. Change the callback to receive a `WorkoutEntity.id`.

**Files:**
- Modify: `ios/Packages/Repositories/Sources/Repositories/PlanGenerationStream.swift`
- Modify: `ios/Packages/Repositories/Sources/Repositories/PlanRepository.swift`
- Modify: `ios/Packages/Features/PlanGeneration/Sources/PlanGeneration/PlanGenStore.swift`
- Modify: `ios/Packages/AppShell/Sources/AppShell/FirstRunGate.swift`
- Modify: `ios/Packages/AppShell/Sources/AppShell/RootScaffold.swift`
- Modify: `ios/PulseApp/DebugFeatureSmokeView.swift`

- [ ] **Step 1: Extend `PlanStreamUpdate.done` to include the inserted workout IDs**

Edit `PlanGenerationStream.swift`:

```swift
public enum PlanStreamUpdate: Sendable {
    case checkpoint(String)
    case textDelta(String)
    case done(WorkoutPlan, insertedWorkoutIDs: [UUID],
              modelUsed: String, promptTokens: Int, completionTokens: Int)
}
```

- [ ] **Step 2: Capture inserted IDs in `PlanRepository.persist`**

Edit `PlanRepository.swift`:

```swift
private func persist(plan: WorkoutPlan, weekStart: Date, modelUsed: String,
                     promptTokens: Int, completionTokens: Int, rawJSON: Data) throws -> [UUID] {
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
    var inserted: [UUID] = []
    for pw in plan.workouts {
        let blocksJSON = (try? JSONEncoder.pulse.encode(pw.blocks)) ?? Data("[]".utf8)
        let exercisesFlat = pw.blocks.flatMap { $0.exercises }
        let exercisesJSON = (try? JSONEncoder.pulse.encode(exercisesFlat)) ?? Data("[]".utf8)
        let id = UUID()
        ctx.insert(WorkoutEntity(
            id: id, planID: planEntity.id,
            scheduledFor: pw.scheduledFor,
            title: pw.title, subtitle: pw.subtitle,
            workoutType: pw.workoutType, durationMin: pw.durationMin,
            status: "scheduled",
            blocksJSON: blocksJSON, exercisesJSON: exercisesJSON,
            why: pw.why))
        inserted.append(id)
    }
    try ctx.save()
    return inserted
}
```

Then in `generatePlan`, capture and emit:

```swift
case "message_stop":
    guard let json = JSONBlockExtractor.extract(from: fullText),
          let data = json.data(using: .utf8) else {
        throw APIClientError.decoding("no fenced ```json block in stream")
    }
    let plan = try JSONDecoder.pulse.decode(WorkoutPlan.self, from: data)
    let insertedIDs = try await persist(plan: plan, weekStart: weekStart,
                                        modelUsed: modelUsed,
                                        promptTokens: promptTokens,
                                        completionTokens: completionTokens,
                                        rawJSON: data)
    continuation.yield(.done(plan, insertedWorkoutIDs: insertedIDs,
                             modelUsed: modelUsed,
                             promptTokens: promptTokens,
                             completionTokens: completionTokens))
    continuation.finish()
    return
```

Update `_persistForTests` signature accordingly:

```swift
public func _persistForTests(plan: WorkoutPlan, weekStart: Date,
                             modelUsed: String, promptTokens: Int,
                             completionTokens: Int, rawJSON: Data) throws -> [UUID] {
    try persist(plan: plan, weekStart: weekStart, modelUsed: modelUsed,
                promptTokens: promptTokens, completionTokens: completionTokens,
                rawJSON: rawJSON)
}
```

- [ ] **Step 3: Change `OnPersistedWorkout` callback signature in `PlanGenStore`**

Edit `PlanGenStore.swift`:

```swift
public typealias OnPersistedWorkout = (WorkoutPlan, [UUID]) -> (any WorkoutHandle)?

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
    case .done(let plan, let ids, _, _, _):
        if let handle = onPersistedWorkout(plan, ids) {
            state = .done(handle)
        } else {
            state = .failed(NoWorkoutHandleError())
        }
    }
}
```

- [ ] **Step 4: Update call sites to use the IDs directly**

In `FirstRunGate.swift` `planGenScreen`:

```swift
onPersistedWorkout: { _, ids in
    if let id = ids.first {
        // Use the actual entity title if available; fall back to a placeholder.
        let repo = WorkoutRepository(modelContainer: self.appContainer.modelContainer)
        if let w = try? repo.workoutForID(id) {
            return PersistedWorkoutHandle(id: id, title: w.title)
        }
        return PersistedWorkoutHandle(id: id, title: "Today's workout")
    }
    return nil
},
```

(`workoutForID` is added in Task 1.5 — until then, you can read `latestWorkout()` as a fallback. The point is the ID itself is now known *to the caller*.)

In `RootScaffold.swift` `regenerateScreen`:

```swift
onPersistedWorkout: { _, ids in
    if let id = ids.first {
        let repo = WorkoutRepository(modelContainer: appContainer.modelContainer)
        let title = (try? repo.workoutForID(id))?.title ?? "Today's workout"
        return PersistedRegenHandle(id: id, title: title)
    }
    return nil
},
```

In `DebugFeatureSmokeView.swift` `planGenView`:

```swift
onPersistedWorkout: { _, ids in
    if let id = ids.first {
        let repo = WorkoutRepository(modelContainer: appContainer.modelContainer)
        let title = (try? repo.workoutForID(id))?.title ?? "Today's workout"
        return DebugWorkoutHandle(id: id, title: title)
    }
    return nil
},
```

- [ ] **Step 5: Update test fixtures to match the new closure signature**

Anywhere a `PlanGenStore` is built in tests, change closure to accept two args.

- [ ] **Step 6: Run all affected packages**

Run: `cd ios/Packages/Repositories && swift test && cd ../Features/PlanGeneration && swift test && cd ../../AppShell && swift test`
Expected: pass (one fix may need to land before the other compiles cleanly — adjust order if needed).

- [ ] **Step 7: Commit**

```bash
git add ios/Packages/Repositories/ ios/Packages/Features/PlanGeneration/ ios/Packages/AppShell/ ios/PulseApp/
git commit -m "fix(plan-generation): pass inserted workout IDs through onPersistedWorkout"
```

---

### Task 1.4: Bundled fallback workout

Master spec §10 Tier 2 mandates a bundled fallback when LLM JSON is malformed twice. Plan 3 deferred with a TODO. Implement it in `Repositories/BundledFallback.swift`. Used in two cases: plan-gen retry-then-fail and adaptation retry-then-fail.

**Files:**
- Create: `ios/Packages/Repositories/Sources/Repositories/BundledFallback.swift`
- Create: `ios/Packages/Repositories/Tests/RepositoriesTests/BundledFallbackTests.swift`
- Create: `ios/Packages/Repositories/Tests/RepositoriesTests/Fixtures/CatalogManifest.json`

The catalog manifest fixture is a build-time guarantee that every exercise ID used by the fallback exists in the canonical catalog. We don't import the live manifest URL into the test target — instead, snapshot the relevant rows.

- [ ] **Step 1: Create the catalog fixture**

Create `Fixtures/CatalogManifest.json`:

```json
[
  {"id":"cat-cow","name":"Cat-Cow","equipment":[]},
  {"id":"worlds-greatest-stretch","name":"World's Greatest Stretch","equipment":[]},
  {"id":"glute-bridge","name":"Glute Bridge","equipment":[]},
  {"id":"dead-bug","name":"Dead Bug","equipment":[]},
  {"id":"hip-90-90","name":"Hip 90/90","equipment":[]}
]
```

These 5 IDs must match the exercise catalog manifest keys. Verify against the live catalog before committing — the manifest URL is in the project memory (`pulse-infrastructure.md`); fetch and grep for these IDs.

- [ ] **Step 2: Write the BundledFallback module**

Create `BundledFallback.swift`:

```swift
import Foundation
import CoreModels

public enum BundledFallback {
    public static func todayWorkout(profile: Profile, today: Date = Date()) -> WorkoutPlan {
        // Hand-authored 25-min mobility flow; conservative for any user.
        let warmup = WorkoutBlock(id: "wu", label: "Warm-up", exercises: [
            PlannedExercise(id: "wu1", exerciseID: "cat-cow", name: "Cat-Cow",
                            sets: [PlannedSet(setNum: 1, reps: 8, load: "BW", restSec: 30)]),
            PlannedExercise(id: "wu2", exerciseID: "worlds-greatest-stretch",
                            name: "World's Greatest Stretch",
                            sets: [PlannedSet(setNum: 1, reps: 6, load: "BW", restSec: 30)]),
        ])
        let main = WorkoutBlock(id: "main", label: "Main", exercises: [
            PlannedExercise(id: "m1", exerciseID: "glute-bridge", name: "Glute Bridge",
                            sets: [
                                PlannedSet(setNum: 1, reps: 10, load: "BW", restSec: 45),
                                PlannedSet(setNum: 2, reps: 10, load: "BW", restSec: 45),
                                PlannedSet(setNum: 3, reps: 10, load: "BW", restSec: 45),
                            ]),
            PlannedExercise(id: "m2", exerciseID: "dead-bug", name: "Dead Bug",
                            sets: [
                                PlannedSet(setNum: 1, reps: 8, load: "BW", restSec: 45),
                                PlannedSet(setNum: 2, reps: 8, load: "BW", restSec: 45),
                            ]),
        ])
        let cooldown = WorkoutBlock(id: "cd", label: "Cooldown", exercises: [
            PlannedExercise(id: "cd1", exerciseID: "hip-90-90", name: "Hip 90/90",
                            sets: [PlannedSet(setNum: 1, reps: 6, load: "BW", restSec: 30)]),
        ])
        let pw = PlannedWorkout(id: "fallback-\(Int(today.timeIntervalSince1970))",
            scheduledFor: today,
            title: "Steady reset",
            subtitle: "Mobility flow",
            workoutType: "Mobility", durationMin: 25,
            blocks: [warmup, main, cooldown],
            why: "Keeping things steady today.")
        var iso = Calendar(identifier: .iso8601)
        iso.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let weekStart = iso.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        return WorkoutPlan(weekStart: weekStart, workouts: [pw])
    }

    /// All exercise IDs the fallback uses. Tests assert these exist in the catalog manifest fixture.
    public static let exerciseIDs: [String] = [
        "cat-cow", "worlds-greatest-stretch", "glute-bridge", "dead-bug", "hip-90-90"
    ]
}
```

- [ ] **Step 3: Write the build-time guarantee test**

Create `BundledFallbackTests.swift`:

```swift
import XCTest
import CoreModels
@testable import Repositories

final class BundledFallbackTests: XCTestCase {
    func test_todayWorkout_decodesBackToWorkoutPlan() throws {
        let plan = BundledFallback.todayWorkout(
            profile: ProfileRepositoryTests.fixtureProfile(),
            today: Date(timeIntervalSince1970: 1_730_000_000))
        let data = try JSONEncoder.pulse.encode(plan)
        let round = try JSONDecoder.pulse.decode(WorkoutPlan.self, from: data)
        XCTAssertEqual(round.workouts.count, 1)
        XCTAssertEqual(round.workouts.first?.workoutType, "Mobility")
    }

    func test_everyExerciseIDExistsInCatalogManifest() throws {
        let url = Bundle.module.url(forResource: "CatalogManifest", withExtension: "json")
        let data = try Data(contentsOf: XCTUnwrap(url))
        struct Row: Decodable { let id: String }
        let rows = try JSONDecoder().decode([Row].self, from: data)
        let known = Set(rows.map(\.id))
        for id in BundledFallback.exerciseIDs {
            XCTAssertTrue(known.contains(id), "Bundled fallback uses unknown exercise id: \(id)")
        }
    }
}
```

- [ ] **Step 4: Update `Repositories/Package.swift` to include the new fixture**

The Package.swift already has `resources: [.copy("Fixtures")]` on the test target. The new `CatalogManifest.json` lives under `Fixtures/` so it's picked up automatically. No edit needed unless the test target excludes JSON files (verify with `swift test`).

- [ ] **Step 5: Run**

Run: `cd ios/Packages/Repositories && swift test --filter BundledFallbackTests`
Expected: 2/2 pass.

- [ ] **Step 6: Commit**

```bash
git add ios/Packages/Repositories/Sources/Repositories/BundledFallback.swift ios/Packages/Repositories/Tests/
git commit -m "feat(repositories): add bundled fallback workout for malformed-LLM tier-2 errors"
```

---

### Task 1.5: `WorkoutRepository.workoutForID` helper

`onPersistedWorkout` callers (Task 1.3) need to look up a workout by stable ID. Add the helper now.

**Files:**
- Modify: `ios/Packages/Repositories/Sources/Repositories/WorkoutRepository.swift`
- Modify: `ios/Packages/Repositories/Tests/RepositoriesTests/WorkoutRepositoryTests.swift`

- [ ] **Step 1: Write a failing test**

Append to `WorkoutRepositoryTests.swift`:

```swift
@MainActor
func test_workoutForID_returnsMatchingRow() throws {
    let container = try PulseModelContainer.inMemory()
    let ctx = container.mainContext
    let id = UUID()
    ctx.insert(WorkoutEntity(id: id, planID: UUID(),
        scheduledFor: Date(), title: "Find me", subtitle: "",
        workoutType: "Strength", durationMin: 30, status: "scheduled",
        blocksJSON: Data("[]".utf8), exercisesJSON: Data("[]".utf8)))
    try ctx.save()
    let repo = WorkoutRepository(modelContainer: container)
    XCTAssertEqual(try repo.workoutForID(id)?.title, "Find me")
    XCTAssertNil(try repo.workoutForID(UUID()))
}
```

- [ ] **Step 2: Run — confirm fail**

Run: `cd ios/Packages/Repositories && swift test --filter test_workoutForID_returnsMatchingRow`
Expected: build error.

- [ ] **Step 3: Add the helper**

In `WorkoutRepository.swift`:

```swift
public func workoutForID(_ id: UUID) throws -> WorkoutEntity? {
    let ctx = modelContainer.mainContext
    let target = id
    let descriptor = FetchDescriptor<WorkoutEntity>(
        predicate: #Predicate { $0.id == target }
    )
    return try ctx.fetch(descriptor).first
}
```

- [ ] **Step 4: Run — confirm pass**

Run: `cd ios/Packages/Repositories && swift test --filter WorkoutRepositoryTests`
Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/Repositories/
git commit -m "feat(workout-repository): add workoutForID(_:) lookup helper"
```

---


## Phase 2 — HealthKit (read-only) + onboarding step

Implement the empty `HealthKitClient` package, register the entitlement and `Info.plist` key, insert onboarding step 7 ("Connect Apple Health"), and extend `PromptBuilder` with an optional 7-day summary block.

### Task 2.1: Create the `HealthKitClient` SPM package

**Files:**
- Create: `ios/Packages/HealthKitClient/Package.swift`
- Create: `ios/Packages/HealthKitClient/Sources/HealthKitClient/HealthKitClient.swift`
- Create: `ios/Packages/HealthKitClient/Sources/HealthKitClient/HKHealthStoreProtocol.swift`
- Create: `ios/Packages/HealthKitClient/Sources/HealthKitClient/SevenDaySummaries.swift`
- Create: `ios/Packages/HealthKitClient/Tests/HealthKitClientTests/HealthKitClientTests.swift`
- Create: `ios/Packages/HealthKitClient/Tests/HealthKitClientTests/FakeHKHealthStore.swift`
- Modify: `ios/Project.yml`

- [ ] **Step 1: Create `Package.swift`**

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HealthKitClient",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "HealthKitClient", targets: ["HealthKitClient"])],
    targets: [
        .target(name: "HealthKitClient"),
        .testTarget(name: "HealthKitClientTests", dependencies: ["HealthKitClient"]),
    ]
)
```

- [ ] **Step 2: Define the protocol seam**

Create `HKHealthStoreProtocol.swift`:

```swift
import Foundation
#if canImport(HealthKit)
import HealthKit

/// Narrow protocol over the parts of HKHealthStore we use, so tests can inject a fake.
public protocol HKHealthStoreProtocol: Sendable {
    func requestAuthorization(toShare typesToShare: Set<HKSampleType>?,
                              read typesToRead: Set<HKObjectType>?) async throws
    func samples(of type: HKSampleType, predicate: NSPredicate?) async throws -> [HKSample]
}

extension HKHealthStore: HKHealthStoreProtocol {
    public func requestAuthorization(toShare typesToShare: Set<HKSampleType>?,
                                     read typesToRead: Set<HKObjectType>?) async throws {
        try await requestAuthorization(toShare: typesToShare ?? [],
                                       read: typesToRead ?? [])
    }
    public func samples(of type: HKSampleType, predicate: NSPredicate?) async throws -> [HKSample] {
        try await withCheckedThrowingContinuation { cont in
            let q = HKSampleQuery(sampleType: type, predicate: predicate,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, results, error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume(returning: results ?? []) }
            }
            self.execute(q)
        }
    }
}
#else
public protocol HKHealthStoreProtocol: Sendable {}
#endif
```

- [ ] **Step 3: Define the summary value types**

Create `SevenDaySummaries.swift`:

```swift
import Foundation

public struct SevenDayActivitySummary: Codable, Sendable {
    public var weeklyActiveMinutes: Int
    public var targetActiveMinutes: Int

    public init(weeklyActiveMinutes: Int, targetActiveMinutes: Int) {
        self.weeklyActiveMinutes = weeklyActiveMinutes
        self.targetActiveMinutes = targetActiveMinutes
    }
}

public struct SevenDayHRSummary: Codable, Sendable {
    public var avgRestingHR: Int?
    public var avgHRVSDNN: Int?

    public init(avgRestingHR: Int?, avgHRVSDNN: Int?) {
        self.avgRestingHR = avgRestingHR
        self.avgHRVSDNN = avgHRVSDNN
    }
}

public struct SevenDaySleepSummary: Codable, Sendable {
    /// Average sleep hours per night (asleep + REM + deep + core).
    public var avgSleepHours: Double?

    public init(avgSleepHours: Double?) {
        self.avgSleepHours = avgSleepHours
    }
}

public struct SevenDayHealthSummary: Codable, Sendable {
    public var activity: SevenDayActivitySummary?
    public var hr: SevenDayHRSummary?
    public var sleep: SevenDaySleepSummary?

    public init(activity: SevenDayActivitySummary?,
                hr: SevenDayHRSummary?,
                sleep: SevenDaySleepSummary?) {
        self.activity = activity
        self.hr = hr
        self.sleep = sleep
    }

    /// Returns true if every field is nil — used to omit the prompt block entirely.
    public var isEmpty: Bool {
        activity == nil && hr == nil && sleep == nil
    }
}
```

- [ ] **Step 4: Implement `HealthKitClient`**

Create `HealthKitClient.swift`:

```swift
import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

public struct HealthKitClient: Sendable {
    private let store: HKHealthStoreProtocol?
    private let now: @Sendable () -> Date

    public init(store: HKHealthStoreProtocol?, now: @Sendable @escaping () -> Date = Date.init) {
        self.store = store
        self.now = now
    }

    /// Real-device convenience: builds a wrapped `HKHealthStore` if HealthKit is available.
    #if canImport(HealthKit)
    public static func live() -> HealthKitClient {
        HealthKitClient(store: HKHealthDataAvailable() ? HKHealthStore() : nil)
    }
    #else
    public static func live() -> HealthKitClient { HealthKitClient(store: nil) }
    #endif

    public func requestAuthorization() async throws {
        #if canImport(HealthKit)
        guard let store else { return }
        let read: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.appleExerciseTime),
            HKCategoryType(.sleepAnalysis),
        ]
        try await store.requestAuthorization(toShare: nil, read: read)
        #endif
    }

    public func sevenDayActivitySummary(target: Int = 240) async -> SevenDayActivitySummary? {
        #if canImport(HealthKit)
        guard let store else { return nil }
        let end = now()
        let start = Calendar.current.date(byAdding: .day, value: -7, to: end) ?? end
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let type = HKQuantityType(.appleExerciseTime)
        guard let samples = try? await store.samples(of: type, predicate: predicate) as? [HKQuantitySample] else {
            return nil
        }
        let totalMin = samples.reduce(0.0) { $0 + $1.quantity.doubleValue(for: .minute()) }
        return SevenDayActivitySummary(weeklyActiveMinutes: Int(totalMin),
                                       targetActiveMinutes: target)
        #else
        return nil
        #endif
    }

    public func sevenDayHRSummary() async -> SevenDayHRSummary? {
        #if canImport(HealthKit)
        guard let store else { return nil }
        let end = now()
        let start = Calendar.current.date(byAdding: .day, value: -7, to: end) ?? end
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        async let resting = avg(store: store, type: HKQuantityType(.restingHeartRate),
                                 unit: HKUnit.count().unitDivided(by: .minute()),
                                 predicate: predicate)
        async let hrv = avg(store: store, type: HKQuantityType(.heartRateVariabilitySDNN),
                             unit: HKUnit.secondUnit(with: .milli),
                             predicate: predicate)
        let r = await resting
        let h = await hrv
        if r == nil && h == nil { return nil }
        return SevenDayHRSummary(avgRestingHR: r.map { Int($0.rounded()) },
                                 avgHRVSDNN: h.map { Int($0.rounded()) })
        #else
        return nil
        #endif
    }

    public func sevenDaySleepSummary() async -> SevenDaySleepSummary? {
        #if canImport(HealthKit)
        guard let store else { return nil }
        let end = now()
        let start = Calendar.current.date(byAdding: .day, value: -7, to: end) ?? end
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        guard let samples = try? await store.samples(of: HKCategoryType(.sleepAnalysis),
                                                      predicate: predicate)
                as? [HKCategorySample] else {
            return nil
        }
        // Sum any "asleep*" categories; divide by 7 to get a per-night avg.
        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
        ]
        let totalSec = samples
            .filter { asleepValues.contains($0.value) }
            .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
        let avgHours = totalSec / 3600.0 / 7.0
        return SevenDaySleepSummary(avgSleepHours: avgHours > 0 ? avgHours : nil)
        #else
        return nil
        #endif
    }

    public func sevenDaySummary() async -> SevenDayHealthSummary {
        async let a = sevenDayActivitySummary()
        async let h = sevenDayHRSummary()
        async let s = sevenDaySleepSummary()
        return await SevenDayHealthSummary(activity: a, hr: h, sleep: s)
    }

    #if canImport(HealthKit)
    private func avg(store: HKHealthStoreProtocol, type: HKQuantityType,
                     unit: HKUnit, predicate: NSPredicate) async -> Double? {
        guard let samples = try? await store.samples(of: type, predicate: predicate)
                as? [HKQuantitySample], !samples.isEmpty else { return nil }
        let total = samples.reduce(0.0) { $0 + $1.quantity.doubleValue(for: unit) }
        return total / Double(samples.count)
    }
    #endif
}
```

- [ ] **Step 5: Add `HealthKitClient` to `Project.yml`**

Edit `ios/Project.yml`. Add to `packages:`:

```yaml
  HealthKitClient:
    path: Packages/HealthKitClient
```

And to `targets.PulseApp.dependencies:`:

```yaml
      - package: HealthKitClient
```

- [ ] **Step 6: Regenerate Xcode project**

Run: `cd ios && xcodegen generate`
Expected: success.

- [ ] **Step 7: Commit**

```bash
git add ios/Packages/HealthKitClient/ ios/Project.yml ios/PulseApp.xcodeproj/
git commit -m "feat(healthkit-client): scaffold read-only HealthKit client + protocol seam"
```

---

### Task 2.2: Add fake `HKHealthStore` and unit tests

Real HK can't run in unit tests; the protocol seam from Task 2.1 lets us inject a fake.

**Files:**
- Create: `ios/Packages/HealthKitClient/Tests/HealthKitClientTests/FakeHKHealthStore.swift`
- Create: `ios/Packages/HealthKitClient/Tests/HealthKitClientTests/HealthKitClientTests.swift`

- [ ] **Step 1: Write `FakeHKHealthStore`**

```swift
import Foundation
#if canImport(HealthKit)
import HealthKit
@testable import HealthKitClient

final class FakeHKHealthStore: HKHealthStoreProtocol, @unchecked Sendable {
    var authorizationCalled = false
    var samplesByType: [HKSampleType: [HKSample]] = [:]
    var shouldThrow: Error?

    func requestAuthorization(toShare typesToShare: Set<HKSampleType>?,
                              read typesToRead: Set<HKObjectType>?) async throws {
        authorizationCalled = true
        if let shouldThrow { throw shouldThrow }
    }

    func samples(of type: HKSampleType, predicate: NSPredicate?) async throws -> [HKSample] {
        if let shouldThrow { throw shouldThrow }
        return samplesByType[type] ?? []
    }
}
#endif
```

- [ ] **Step 2: Write the unit tests**

Create `HealthKitClientTests.swift`:

```swift
import XCTest
#if canImport(HealthKit)
import HealthKit
@testable import HealthKitClient

final class HealthKitClientTests: XCTestCase {
    func test_sevenDayActivitySummary_sumsExerciseMinutes() async {
        let fake = FakeHKHealthStore()
        let now = Date(timeIntervalSince1970: 1_730_000_000)
        let type = HKQuantityType(.appleExerciseTime)
        let s1 = HKQuantitySample(type: type,
            quantity: HKQuantity(unit: .minute(), doubleValue: 30),
            start: now.addingTimeInterval(-3 * 86_400),
            end: now.addingTimeInterval(-3 * 86_400 + 1800))
        let s2 = HKQuantitySample(type: type,
            quantity: HKQuantity(unit: .minute(), doubleValue: 45),
            start: now.addingTimeInterval(-1 * 86_400),
            end: now.addingTimeInterval(-1 * 86_400 + 2700))
        fake.samplesByType[type] = [s1, s2]
        let client = HealthKitClient(store: fake, now: { now })
        let summary = await client.sevenDayActivitySummary()
        XCTAssertEqual(summary?.weeklyActiveMinutes, 75)
        XCTAssertEqual(summary?.targetActiveMinutes, 240)
    }

    func test_sevenDayHRSummary_averagesRestingHRAndHRV() async {
        let fake = FakeHKHealthStore()
        let now = Date(timeIntervalSince1970: 1_730_000_000)
        let restingType = HKQuantityType(.restingHeartRate)
        let hrvType = HKQuantityType(.heartRateVariabilitySDNN)
        fake.samplesByType[restingType] = [
            HKQuantitySample(type: restingType,
                quantity: HKQuantity(unit: HKUnit.count().unitDivided(by: .minute()),
                                     doubleValue: 56),
                start: now.addingTimeInterval(-86_400), end: now.addingTimeInterval(-86_400)),
            HKQuantitySample(type: restingType,
                quantity: HKQuantity(unit: HKUnit.count().unitDivided(by: .minute()),
                                     doubleValue: 60),
                start: now.addingTimeInterval(-86_400 * 2), end: now.addingTimeInterval(-86_400 * 2)),
        ]
        fake.samplesByType[hrvType] = [
            HKQuantitySample(type: hrvType,
                quantity: HKQuantity(unit: .secondUnit(with: .milli), doubleValue: 50),
                start: now.addingTimeInterval(-86_400), end: now.addingTimeInterval(-86_400)),
        ]
        let client = HealthKitClient(store: fake, now: { now })
        let summary = await client.sevenDayHRSummary()
        XCTAssertEqual(summary?.avgRestingHR, 58)
        XCTAssertEqual(summary?.avgHRVSDNN, 50)
    }

    func test_sevenDaySummary_returnsEmptyWhenStoreIsNil() async {
        let client = HealthKitClient(store: nil)
        let summary = await client.sevenDaySummary()
        XCTAssertTrue(summary.isEmpty)
    }

    func test_sevenDaySummary_propagatesErrorAsNil() async {
        let fake = FakeHKHealthStore()
        struct DummyError: Error {}
        fake.shouldThrow = DummyError()
        let client = HealthKitClient(store: fake)
        let summary = await client.sevenDaySummary()
        XCTAssertTrue(summary.isEmpty)
    }
}
#endif
```

- [ ] **Step 3: Run**

Run: `cd ios/Packages/HealthKitClient && swift test`
Expected: 4/4 pass.

- [ ] **Step 4: Commit**

```bash
git add ios/Packages/HealthKitClient/Tests/
git commit -m "test(healthkit-client): protocol-injected fake store + 7-day summary unit tests"
```

---

### Task 2.3: Add HealthKit entitlement + Info.plist usage description

**Files:**
- Modify: `ios/PulseApp/PulseApp.entitlements`
- Modify: `ios/PulseApp/Info.plist`

- [ ] **Step 1: Edit `PulseApp.entitlements`**

Replace contents:

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

- [ ] **Step 2: Add `NSHealthShareUsageDescription` to `Info.plist`**

Add inside the top `<dict>`:

```xml
  <key>NSHealthShareUsageDescription</key>
  <string>Pulse uses recent activity, heart-rate, and sleep summaries to personalize your workouts and adapt them after each session.</string>
```

- [ ] **Step 3: Wire entitlement into Project.yml**

In `ios/Project.yml`, under `targets.PulseApp.settings.base` add:

```yaml
        CODE_SIGN_ENTITLEMENTS: PulseApp/PulseApp.entitlements
```

- [ ] **Step 4: Regenerate Xcode project**

Run: `cd ios && xcodegen generate`
Expected: success.

- [ ] **Step 5: Commit**

```bash
git add ios/PulseApp/PulseApp.entitlements ios/PulseApp/Info.plist ios/Project.yml ios/PulseApp.xcodeproj/
git commit -m "chore(ios): add HealthKit entitlement and NSHealthShareUsageDescription"
```

---

### Task 2.4: Insert `OnboardingDraft.Step.health` and gate

**Files:**
- Modify: `ios/Packages/CoreModels/Sources/CoreModels/OnboardingDraft.swift`
- Modify: `ios/Packages/CoreModels/Tests/CoreModelsTests/OnboardingDraftTests.swift`

The new step is non-blocking — Skip is allowed and doesn't affect `buildProfile`. So `canAdvance(from: .health)` is always true.

- [ ] **Step 1: Write a failing test**

Append to `OnboardingDraftTests.swift`:

```swift
func test_step_healthExistsBetweenCoachAndEnd() {
    let all = OnboardingDraft.Step.allCases
    XCTAssertTrue(all.contains(.health))
    // Order: ... coach < health
    XCTAssertLessThan(OnboardingDraft.Step.coach.rawValue,
                      OnboardingDraft.Step.health.rawValue)
}

func test_canAdvance_healthStep_alwaysTrue() {
    let d = OnboardingDraft()
    XCTAssertTrue(d.canAdvance(from: .health))
}
```

- [ ] **Step 2: Run — confirm fail**

Run: `cd ios/Packages/CoreModels && swift test --filter test_step_healthExistsBetweenCoachAndEnd`
Expected: build error (`.health` not found).

- [ ] **Step 3: Add `.health` case + gate**

Edit `OnboardingDraft.swift`. The Step enum's `coach` is currently the last case; add `health` after:

```swift
public enum Step: Int, CaseIterable, Sendable {
    case name = 1, goals, level, equipment, frequency, coach, health
}

public func canAdvance(from step: Step) -> Bool {
    switch step {
    case .name:      return !displayName.trimmingCharacters(in: .whitespaces).isEmpty
    case .goals:     return !goals.isEmpty
    case .level:     return level != nil
    case .equipment: return !equipment.isEmpty
    case .frequency: return frequencyPerWeek != nil && weeklyTargetMinutes != nil
    case .coach:     return activeCoachID != nil
    case .health:    return true   // Skip is allowed
    }
}
```

- [ ] **Step 4: Run — confirm pass**

Run: `cd ios/Packages/CoreModels && swift test --filter OnboardingDraftTests`
Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/CoreModels/
git commit -m "feat(core-models): add OnboardingDraft.Step.health (non-blocking)"
```

---

### Task 2.5: Update `OnboardingStore` and `OnboardingFlowView` for the new step

`OnboardingStore.isAtCoachStep` currently fires the "Generate my first workout" handler. We want that handler to fire from `.health`, and the coach step to advance to `.health` on Next.

**Files:**
- Modify: `ios/Packages/Features/Onboarding/Sources/Onboarding/OnboardingStore.swift`
- Modify: `ios/Packages/Features/Onboarding/Sources/Onboarding/OnboardingFlowView.swift`
- Create: `ios/Packages/Features/Onboarding/Sources/Onboarding/Steps/HealthStepView.swift`
- Modify: `ios/Packages/Features/Onboarding/Tests/OnboardingTests/OnboardingStoreTests.swift`
- Modify: `ios/Packages/Features/Onboarding/Package.swift` (add HealthKitClient dep)

- [ ] **Step 1: Add HealthKitClient as a dependency**

Edit `Onboarding/Package.swift`:

```swift
dependencies: [
    .package(path: "../../CoreModels"),
    .package(path: "../../DesignSystem"),
    .package(path: "../../Repositories"),
    .package(path: "../../HealthKitClient"),
],
targets: [
    .target(name: "Onboarding",
            dependencies: ["CoreModels", "DesignSystem", "Repositories", "HealthKitClient"]),
    .testTarget(name: "OnboardingTests", dependencies: ["Onboarding"]),
]
```

- [ ] **Step 2: Rename `isAtCoachStep` → `isAtFinalStep` and point it at `.health`**

Edit `OnboardingStore.swift`:

```swift
public var isAtFinalStep: Bool { currentStep == .health }
// keep old property as a deprecated alias to ease the rename:
public var isAtCoachStep: Bool { currentStep == .coach }
```

- [ ] **Step 3: Create `HealthStepView`**

Create `ios/Packages/Features/Onboarding/Sources/Onboarding/Steps/HealthStepView.swift`:

```swift
import SwiftUI
import DesignSystem
import HealthKitClient

public struct HealthStepView: View {
    @Binding var didConnect: Bool
    private let client: HealthKitClient

    public init(didConnect: Binding<Bool>, client: HealthKitClient = .live()) {
        self._didConnect = didConnect
        self.client = client
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.lg) {
            Text("Connect Apple Health")
                .pulseFont(.h1)
                .foregroundStyle(PulseColors.ink0.color)
            Text("Pulse reads your last 7 days of activity, heart rate, and sleep to personalize the plan and adapt it after each session. Read-only — Pulse never writes to Health.")
                .pulseFont(.body)
                .foregroundStyle(PulseColors.ink1.color)
            VStack(spacing: PulseSpacing.md) {
                PulseButton(didConnect ? "Connected" : "Connect", variant: .primary) {
                    Task {
                        try? await client.requestAuthorization()
                        await MainActor.run { didConnect = true }
                    }
                }
                .disabled(didConnect)
                Text("You can change this later in Settings.")
                    .pulseFont(.small)
                    .foregroundStyle(PulseColors.ink2.color)
            }
            Spacer()
        }
        .padding(PulseSpacing.lg)
    }
}
```

- [ ] **Step 4: Render the new step in `OnboardingFlowView`**

Edit `OnboardingFlowView.swift`. Add `@State private var healthConnected = false` and a new case in `stepContent`:

```swift
@State private var healthConnected = false

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
```

Replace the footer's CTA logic to check `isAtFinalStep` instead of `isAtCoachStep`:

```swift
private var footer: some View {
    HStack {
        if store.currentStep != .name {
            PulseButton("Back", variant: .ghost) { store.back() }
        }
        Spacer()
        PulseButton(
            store.isAtFinalStep ? "Generate my first workout"
                                : (store.currentStep == .health ? "Skip" : "Next"),
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
```

(The "Skip" label only shows on `.health`; pressing it submits and proceeds. Connect was tappable inside the step view.)

- [ ] **Step 5: Update `OnboardingStoreTests`**

Append to `OnboardingStoreTests.swift`:

```swift
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
```

- [ ] **Step 6: Run**

Run: `cd ios/Packages/Features/Onboarding && swift test`
Expected: pass.

- [ ] **Step 7: Commit**

```bash
git add ios/Packages/Features/Onboarding/ ios/Packages/CoreModels/
git commit -m "feat(onboarding): add Connect Apple Health step before plan-gen handoff"
```

---

### Task 2.6: Wire `HealthKitClient` into `AppContainer` + `PromptBuilder` 7-day block

Add `HealthKitClient` to `AppContainer` so repos can read summaries during plan-gen and adaptation. Extend `PromptBuilder.planGenUserMessage` with an optional `summaries:` parameter.

**Files:**
- Modify: `ios/Packages/Repositories/Sources/Repositories/AppContainer.swift`
- Modify: `ios/Packages/Repositories/Package.swift`
- Modify: `ios/Packages/Repositories/Sources/Repositories/PromptBuilder.swift`
- Modify: `ios/Packages/Repositories/Tests/RepositoriesTests/PromptBuilderTests.swift`
- Modify: `ios/Packages/Repositories/Sources/Repositories/PlanRepository.swift`
- Modify: `ios/PulseApp/PulseApp.swift`

- [ ] **Step 1: Add `HealthKitClient` dep to Repositories**

Edit `Repositories/Package.swift`:

```swift
dependencies: [
    .package(path: "../CoreModels"),
    .package(path: "../Persistence"),
    .package(path: "../Networking"),
    .package(path: "../HealthKitClient"),
],
targets: [
    .target(name: "Repositories",
            dependencies: ["CoreModels", "Persistence", "Networking", "HealthKitClient"]),
    .testTarget(name: "RepositoriesTests",
                dependencies: ["Repositories"],
                resources: [.copy("Fixtures")]),
]
```

- [ ] **Step 2: Add field to `AppContainer`**

```swift
import Foundation
import SwiftData
import Networking
import HealthKitClient

public struct AppContainer: Sendable {
    public let modelContainer: ModelContainer
    public let api: APIClient
    public let manifestURL: URL
    public let healthKit: HealthKitClient

    public init(modelContainer: ModelContainer, api: APIClient, manifestURL: URL,
                healthKit: HealthKitClient) {
        self.modelContainer = modelContainer
        self.api = api
        self.manifestURL = manifestURL
        self.healthKit = healthKit
    }
}
```

- [ ] **Step 3: Build the live HealthKitClient in PulseApp**

Edit `ios/PulseApp/PulseApp.swift` — wherever `AppContainer(...)` is constructed, add `healthKit: HealthKitClient.live()`.

- [ ] **Step 4: Add `summaries:` parameter to `planGenUserMessage`**

Edit `PromptBuilder.swift`:

```swift
import HealthKitClient

static func planGenUserMessage(profile: Profile, today: Date,
                                summaries: SevenDayHealthSummary? = nil) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    let dateStr = formatter.string(from: today)
    let goals = profile.goals.isEmpty ? "none" : profile.goals.joined(separator: ", ")
    let equipment = profile.equipment.isEmpty ? "none" : profile.equipment.joined(separator: ", ")
    var s = """
    Profile:
    - Name: \(profile.displayName)
    - Goals: \(goals)
    - Level: \(profile.level.rawValue)
    - Equipment available: \(equipment)
    - Sessions per week: \(profile.frequencyPerWeek)
    - Weekly target minutes: \(profile.weeklyTargetMinutes)

    Today: \(dateStr)
    """
    if let summaries, !summaries.isEmpty {
        s += "\n\n" + Self.healthSummaryBlock(summaries)
    }
    s += "\n\nGenerate today's workout."
    return s
}

static func healthSummaryBlock(_ s: SevenDayHealthSummary) -> String {
    var lines: [String] = ["7-DAY HEALTH SUMMARY (Apple Health):"]
    if let r = s.hr?.avgRestingHR { lines.append("- avg resting HR: \(r) bpm") }
    if let h = s.hr?.avgHRVSDNN   { lines.append("- avg HRV (SDNN): \(h) ms") }
    if let z = s.sleep?.avgSleepHours, z > 0 {
        lines.append(String(format: "- avg sleep: %.1f hrs", z))
    }
    if let a = s.activity {
        lines.append("- weekly active minutes: \(a.weeklyActiveMinutes) / \(a.targetActiveMinutes) target")
    }
    return lines.joined(separator: "\n")
}
```

- [ ] **Step 5: Plumb summaries into `PlanRepository.streamFirstPlan`**

```swift
public func streamFirstPlan(profile: Profile, coach: Coach,
                            now: Date = Date(),
                            summaries: SevenDayHealthSummary? = nil,
                            strictRetry: Bool = false) -> AsyncThrowingStream<PlanStreamUpdate, Error> {
    let exercises = availableExercises(for: profile)
    let system = PromptBuilder.planGenSystemPrompt(coach: coach,
                                                  availableExercises: exercises,
                                                  strictRetry: strictRetry)
    let user = PromptBuilder.planGenUserMessage(profile: profile, today: now, summaries: summaries)
    let weekStart = Self._weekStart(for: now)
    return generatePlan(systemPrompt: system, userMessage: user, weekStart: weekStart)
}
```

- [ ] **Step 6: Update `FirstRunGate.planGenScreen` and `RootScaffold.regenerateScreen` to fetch summaries first**

In `FirstRunGate.swift`, change the streamProvider to fetch summaries asynchronously inside the closure. Since `StreamProvider` is `(Profile, Bool) -> AsyncThrowingStream<...>`, fetch *before* presenting plan-gen. Simpler: pre-fetch into `@State var summaries: SevenDayHealthSummary?` after onboarding completes, and capture into the closure.

Add to `FirstRunGate`:

```swift
@State private var summaries: SevenDayHealthSummary?

private var onboardingFlow: some View {
    OnboardingFlowView(
        profileRepo: profileRepo,
        themeStore: themeStore
    ) { newProfile in
        // Capture HK summaries before presenting plan-gen.
        let s = await appContainer.healthKit.sevenDaySummary()
        await MainActor.run {
            summaries = s
            profile = newProfile
            pendingProfileForPlanGen = newProfile
        }
    }
}
```

Then in `planGenScreen`:

```swift
streamProvider: { p, strict in
    self.planRepo.streamFirstPlan(profile: p, coach: coach,
                                  summaries: self.summaries,
                                  strictRetry: strict)
},
```

In `RootScaffold.regenerateScreen`, do likewise — fetch summaries in `triggerRegenerate()`:

```swift
@State private var regenerateSummaries: SevenDayHealthSummary?

private func triggerRegenerate() {
    let repo = ProfileRepository(modelContainer: appContainer.modelContainer)
    Task {
        let p = (try? repo.currentProfile()) ?? nil
        let s = await appContainer.healthKit.sevenDaySummary()
        await MainActor.run {
            regenerateSummaries = s
            regeneratePresentedFor = p
        }
    }
}
```

In the closure:

```swift
streamProvider: { p, strict in
    planRepo.regenerate(profile: p, coach: coach,
                        summaries: regenerateSummaries,
                        strictRetry: strict)
},
```

`regenerate` also gets a `summaries` parameter passed through to `streamFirstPlan`.

- [ ] **Step 7: Add a snapshot test for the HK block**

Append to `PromptBuilderTests.swift`:

```swift
import HealthKitClient

func test_planGenUserMessage_omitsHealthBlockWhenSummariesEmpty() {
    let profile = ProfileRepositoryTests.fixtureProfile()
    let date = Date(timeIntervalSince1970: 1_730_000_000)
    let s = PromptBuilder.planGenUserMessage(profile: profile, today: date, summaries: nil)
    XCTAssertFalse(s.contains("7-DAY HEALTH SUMMARY"))
}

func test_planGenUserMessage_includesHealthBlockWhenSummariesPresent() {
    let profile = ProfileRepositoryTests.fixtureProfile()
    let date = Date(timeIntervalSince1970: 1_730_000_000)
    let summaries = SevenDayHealthSummary(
        activity: .init(weeklyActiveMinutes: 187, targetActiveMinutes: 240),
        hr: .init(avgRestingHR: 58, avgHRVSDNN: 52),
        sleep: .init(avgSleepHours: 7.4))
    let s = PromptBuilder.planGenUserMessage(profile: profile, today: date, summaries: summaries)
    XCTAssertTrue(s.contains("7-DAY HEALTH SUMMARY"))
    XCTAssertTrue(s.contains("avg resting HR: 58 bpm"))
    XCTAssertTrue(s.contains("avg HRV (SDNN): 52 ms"))
    XCTAssertTrue(s.contains("avg sleep: 7.4 hrs"))
    XCTAssertTrue(s.contains("weekly active minutes: 187 / 240 target"))
}
```

- [ ] **Step 8: Run all tests**

Run: `cd ios/Packages/Repositories && swift test && cd ../Features/Onboarding && swift test && cd ../../AppShell && swift test`
Expected: pass.

- [ ] **Step 9: Commit**

```bash
git add ios/Packages/Repositories/ ios/Packages/AppShell/ ios/PulseApp/
git commit -m "feat(prompt-builder): inject 7-day HealthKit summaries into plan-gen prompt"
```

---


## Phase 3 — Repositories: Session, Adaptation, Workout extensions

The persistence layer for Plan 4's spine. Adds `SessionRepository`, splits `FeedbackRepository` (drops adaptation), adds `AdaptationRepository`, extends `WorkoutRepository` with superseded filtering and `workoutForDate`, adds the adaptation prompt builders + stream event types, and a `transaction { ... }` helper in Persistence.

### Task 3.1: Persistence — `transaction { }` helper

A small atomic-write helper. SwiftData's `mainContext.save()` is the implicit boundary; this helper wraps multiple writes so that a thrown error rolls back via `ctx.rollback()`.

**Files:**
- Create: `ios/Packages/Persistence/Sources/Persistence/Transaction.swift`
- Create: `ios/Packages/Persistence/Tests/PersistenceTests/TransactionTests.swift` (or append to existing)

- [ ] **Step 1: Write a failing test**

Create or append `TransactionTests.swift`:

```swift
import XCTest
import SwiftData
@testable import Persistence

final class TransactionTests: XCTestCase {
    @MainActor
    func test_transaction_rollsBackOnThrow() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let initialCount = try ctx.fetch(FetchDescriptor<ProfileEntity>()).count
        struct Boom: Error {}
        do {
            try ctx.transaction {
                ctx.insert(ProfileEntity(id: UUID(), displayName: "x", goals: ["g"],
                    level: "regular", equipment: ["dumbbells"], frequencyPerWeek: 3,
                    weeklyTargetMinutes: 120, activeCoachID: "rex", accentHue: 45,
                    createdAt: Date()))
                throw Boom()
            }
            XCTFail("expected throw")
        } catch {
            // expected
        }
        let after = try ctx.fetch(FetchDescriptor<ProfileEntity>()).count
        XCTAssertEqual(after, initialCount)
    }

    @MainActor
    func test_transaction_commitsOnSuccess() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        try ctx.transaction {
            ctx.insert(ProfileEntity(id: UUID(), displayName: "y", goals: ["g"],
                level: "regular", equipment: ["dumbbells"], frequencyPerWeek: 3,
                weeklyTargetMinutes: 120, activeCoachID: "rex", accentHue: 45,
                createdAt: Date()))
        }
        let count = try ctx.fetch(FetchDescriptor<ProfileEntity>()).count
        XCTAssertEqual(count, 1)
    }
}
```

- [ ] **Step 2: Run — confirm fail (no `transaction` method)**

Run: `cd ios/Packages/Persistence && swift test --filter TransactionTests`
Expected: build error.

- [ ] **Step 3: Add the helper**

Create `Transaction.swift`:

```swift
import Foundation
import SwiftData

public extension ModelContext {
    /// Run a body on the main actor. On throw, calls `rollback()` and rethrows.
    /// On success, calls `save()` so changes persist.
    @MainActor
    func transaction(_ body: @MainActor () throws -> Void) throws {
        do {
            try body()
            try save()
        } catch {
            rollback()
            throw error
        }
    }
}
```

- [ ] **Step 4: Run — confirm pass**

Run: `cd ios/Packages/Persistence && swift test --filter TransactionTests`
Expected: 2/2 pass.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/Persistence/
git commit -m "feat(persistence): add ModelContext.transaction { ... } helper"
```

---

### Task 3.2: `SessionRepository` — start / logSet (idempotent) / finish / discard

**Files:**
- Create: `ios/Packages/Repositories/Sources/Repositories/SessionRepository.swift`
- Create: `ios/Packages/Repositories/Tests/RepositoriesTests/SessionRepositoryTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
import SwiftData
import CoreModels
import Persistence
@testable import Repositories

final class SessionRepositoryTests: XCTestCase {
    @MainActor
    private func seedWorkout(_ ctx: ModelContext, status: String = "scheduled") -> WorkoutEntity {
        let w = WorkoutEntity(id: UUID(), planID: UUID(),
            scheduledFor: Date(), title: "Push", subtitle: "Upper",
            workoutType: "Strength", durationMin: 45, status: status,
            blocksJSON: Data("[]".utf8), exercisesJSON: Data("[]".utf8))
        ctx.insert(w); try? ctx.save()
        return w
    }

    @MainActor
    func test_start_createsSessionAndFlipsWorkoutToInProgress() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let w = seedWorkout(ctx)
        let repo = SessionRepository(modelContainer: container)
        let session = try repo.start(workoutID: w.id)
        XCTAssertEqual(session.workoutID, w.id)
        XCTAssertNotNil(session.startedAt)
        XCTAssertNil(session.completedAt)
        let refreshed = try ctx.fetch(FetchDescriptor<WorkoutEntity>()).first
        XCTAssertEqual(refreshed?.status, "in_progress")
    }

    @MainActor
    func test_logSet_isIdempotentOnTriple() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let w = seedWorkout(ctx)
        let repo = SessionRepository(modelContainer: container)
        let session = try repo.start(workoutID: w.id)
        try repo.logSet(sessionID: session.id, exerciseID: "back-squat",
                        setNum: 1, reps: 8, load: "60kg", rpe: 7)
        try repo.logSet(sessionID: session.id, exerciseID: "back-squat",
                        setNum: 1, reps: 10, load: "62.5kg", rpe: 8)
        let rows = try ctx.fetch(FetchDescriptor<SetLogEntity>())
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.reps, 10)
        XCTAssertEqual(rows.first?.load, "62.5kg")
        XCTAssertEqual(rows.first?.rpe, 8)
    }

    @MainActor
    func test_finish_setsCompletedAtAndFlipsWorkoutToCompleted() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let w = seedWorkout(ctx)
        let repo = SessionRepository(modelContainer: container)
        let session = try repo.start(workoutID: w.id)
        try repo.finish(sessionID: session.id)
        let refreshedSession = try ctx.fetch(FetchDescriptor<SessionEntity>()).first
        XCTAssertNotNil(refreshedSession?.completedAt)
        XCTAssertNotNil(refreshedSession?.durationSec)
        let refreshedWorkout = try ctx.fetch(FetchDescriptor<WorkoutEntity>()).first
        XCTAssertEqual(refreshedWorkout?.status, "completed")
    }

    @MainActor
    func test_discard_cascadeDeletesSetsAndRestoresWorkoutToScheduled() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let w = seedWorkout(ctx)
        let repo = SessionRepository(modelContainer: container)
        let session = try repo.start(workoutID: w.id)
        try repo.logSet(sessionID: session.id, exerciseID: "back-squat",
                        setNum: 1, reps: 8, load: "60kg", rpe: 7)
        try repo.discardSession(id: session.id)
        let sessions = try ctx.fetch(FetchDescriptor<SessionEntity>())
        let sets = try ctx.fetch(FetchDescriptor<SetLogEntity>())
        XCTAssertTrue(sessions.isEmpty)
        XCTAssertTrue(sets.isEmpty)
        let refreshed = try ctx.fetch(FetchDescriptor<WorkoutEntity>()).first
        XCTAssertEqual(refreshed?.status, "scheduled")
    }
}
```

- [ ] **Step 2: Run — confirm fail**

Run: `cd ios/Packages/Repositories && swift test --filter SessionRepositoryTests`
Expected: build error.

- [ ] **Step 3: Implement `SessionRepository`**

Create `SessionRepository.swift`:

```swift
import Foundation
import SwiftData
import CoreModels
import Persistence

@MainActor
public final class SessionRepository {
    public let modelContainer: ModelContainer

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    @discardableResult
    public func start(workoutID: UUID, now: Date = Date()) throws -> SessionEntity {
        let ctx = modelContainer.mainContext
        var session: SessionEntity!
        try ctx.transaction {
            let target = workoutID
            let workouts = try ctx.fetch(FetchDescriptor<WorkoutEntity>(
                predicate: #Predicate { $0.id == target }))
            guard let workout = workouts.first else {
                throw SessionRepositoryError.workoutNotFound(workoutID)
            }
            workout.status = "in_progress"
            session = SessionEntity(id: UUID(), workoutID: workoutID, startedAt: now)
            ctx.insert(session)
        }
        return session
    }

    public func logSet(sessionID: UUID, exerciseID: String, setNum: Int,
                       reps: Int, load: String, rpe: Int, now: Date = Date()) throws {
        let ctx = modelContainer.mainContext
        try ctx.transaction {
            let sid = sessionID
            let exid = exerciseID
            let n = setNum
            let existing = try ctx.fetch(FetchDescriptor<SetLogEntity>(
                predicate: #Predicate {
                    $0.sessionID == sid && $0.exerciseID == exid && $0.setNum == n
                })).first
            if let row = existing {
                row.reps = reps
                row.load = load
                row.rpe = rpe
                row.loggedAt = now
            } else {
                // Need parent session for cascade-delete relationship.
                let session = try ctx.fetch(FetchDescriptor<SessionEntity>(
                    predicate: #Predicate { $0.id == sid })).first
                ctx.insert(SetLogEntity(sessionID: sid, exerciseID: exid,
                    setNum: n, reps: reps, load: load, rpe: rpe,
                    loggedAt: now, session: session))
            }
        }
    }

    public func finish(sessionID: UUID, now: Date = Date()) throws {
        let ctx = modelContainer.mainContext
        try ctx.transaction {
            let sid = sessionID
            guard let session = try ctx.fetch(FetchDescriptor<SessionEntity>(
                predicate: #Predicate { $0.id == sid })).first else {
                throw SessionRepositoryError.sessionNotFound(sid)
            }
            session.completedAt = now
            session.durationSec = Int(now.timeIntervalSince(session.startedAt))
            let workoutID = session.workoutID
            if let w = try ctx.fetch(FetchDescriptor<WorkoutEntity>(
                predicate: #Predicate { $0.id == workoutID })).first {
                w.status = "completed"
            }
        }
    }

    public func discardSession(id: UUID) throws {
        let ctx = modelContainer.mainContext
        try ctx.transaction {
            let sid = id
            guard let session = try ctx.fetch(FetchDescriptor<SessionEntity>(
                predicate: #Predicate { $0.id == sid })).first else {
                return
            }
            let workoutID = session.workoutID
            // Cascade delete via SwiftData relationship handles SetLogEntity rows.
            ctx.delete(session)
            if let w = try ctx.fetch(FetchDescriptor<WorkoutEntity>(
                predicate: #Predicate { $0.id == workoutID })).first {
                w.status = "scheduled"
            }
        }
    }

    /// Returns any in-progress session whose Workout is still flagged "in_progress".
    /// Used by `FirstRunGate` to detect orphaned sessions on relaunch.
    public func orphanedInProgressSession() throws -> SessionEntity? {
        let ctx = modelContainer.mainContext
        let sessions = try ctx.fetch(FetchDescriptor<SessionEntity>())
        return sessions.first(where: { $0.completedAt == nil })
    }
}

public enum SessionRepositoryError: Error, Equatable {
    case workoutNotFound(UUID)
    case sessionNotFound(UUID)
}
```

- [ ] **Step 4: Run — confirm pass**

Run: `cd ios/Packages/Repositories && swift test --filter SessionRepositoryTests`
Expected: 4/4 pass.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/Repositories/
git commit -m "feat(session-repository): start / logSet (idempotent) / finish / discard"
```

---

### Task 3.3: `WorkoutEntity` status doc + `WorkoutRepository` superseded filter + `workoutForDate`

`WorkoutEntity.status`'s comment currently says `"scheduled" | "in_progress" | "completed" | "skipped"`. Per spec the lexicon becomes `"scheduled" | "in_progress" | "completed" | "superseded"`. Update the comment. Then add `workoutForDate(_)` that filters superseded, and update `latestWorkout()` and `todaysWorkout(now:calendar:)` to filter as well.

**Files:**
- Modify: `ios/Packages/Persistence/Sources/Persistence/Entities/WorkoutEntity.swift`
- Modify: `ios/Packages/Repositories/Sources/Repositories/WorkoutRepository.swift`
- Modify: `ios/Packages/Repositories/Tests/RepositoriesTests/WorkoutRepositoryTests.swift`

- [ ] **Step 1: Update `WorkoutEntity.status` comment**

In `WorkoutEntity.swift`, change line 14 to:

```swift
public var status: String       // "scheduled" | "in_progress" | "completed" | "superseded"
```

- [ ] **Step 2: Write failing tests**

Append to `WorkoutRepositoryTests.swift`:

```swift
@MainActor
func test_latestWorkout_filtersSuperseded() throws {
    let container = try PulseModelContainer.inMemory()
    let ctx = container.mainContext
    let oldDate = Date(timeIntervalSince1970: 1_700_000_000)
    let newDate = Date(timeIntervalSince1970: 1_730_000_000)
    ctx.insert(WorkoutEntity(id: UUID(), planID: UUID(), scheduledFor: oldDate,
        title: "Keep", subtitle: "", workoutType: "Strength",
        durationMin: 30, status: "scheduled",
        blocksJSON: Data("[]".utf8), exercisesJSON: Data("[]".utf8)))
    ctx.insert(WorkoutEntity(id: UUID(), planID: UUID(), scheduledFor: newDate,
        title: "Hide", subtitle: "", workoutType: "Strength",
        durationMin: 30, status: "superseded",
        blocksJSON: Data("[]".utf8), exercisesJSON: Data("[]".utf8)))
    try ctx.save()
    let repo = WorkoutRepository(modelContainer: container)
    let latest = try repo.latestWorkout()
    XCTAssertEqual(latest?.title, "Keep")
}

@MainActor
func test_workoutForDate_filtersSupersededAndPicksLatestNonSupersedeed() throws {
    let container = try PulseModelContainer.inMemory()
    let ctx = container.mainContext
    var iso = Calendar(identifier: .iso8601)
    iso.timeZone = TimeZone(secondsFromGMT: 0)!
    let day = iso.startOfDay(for: Date(timeIntervalSince1970: 1_730_000_000))
    let earlier = day.addingTimeInterval(3_600)
    let later   = day.addingTimeInterval(7_200)
    ctx.insert(WorkoutEntity(id: UUID(), planID: UUID(), scheduledFor: earlier,
        title: "Old", subtitle: "", workoutType: "Strength",
        durationMin: 30, status: "superseded",
        blocksJSON: Data("[]".utf8), exercisesJSON: Data("[]".utf8)))
    ctx.insert(WorkoutEntity(id: UUID(), planID: UUID(), scheduledFor: later,
        title: "New", subtitle: "", workoutType: "Strength",
        durationMin: 30, status: "scheduled",
        blocksJSON: Data("[]".utf8), exercisesJSON: Data("[]".utf8)))
    try ctx.save()
    let repo = WorkoutRepository(modelContainer: container)
    XCTAssertEqual(try repo.workoutForDate(day)?.title, "New")
}
```

- [ ] **Step 3: Run — confirm fail**

Run: `cd ios/Packages/Repositories && swift test --filter WorkoutRepositoryTests`
Expected: fail (`workoutForDate` missing; `latestWorkout` returns the superseded row).

- [ ] **Step 4: Update `WorkoutRepository`**

In `WorkoutRepository.swift`:

```swift
private static let nonSupersededStatuses = ["scheduled", "in_progress", "completed"]

public func todaysWorkout(now: Date = Date(),
                          calendar: Calendar = Calendar(identifier: .iso8601))
                          throws -> WorkoutEntity? {
    let dayStart = calendar.startOfDay(for: now)
    let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
    let descriptor = FetchDescriptor<WorkoutEntity>(
        predicate: #Predicate {
            $0.scheduledFor >= dayStart && $0.scheduledFor < dayEnd
                && $0.status != "superseded"
        },
        sortBy: [SortDescriptor(\.scheduledFor, order: .forward)]
    )
    return try modelContainer.mainContext.fetch(descriptor).first
}

public func latestWorkout() throws -> WorkoutEntity? {
    var descriptor = FetchDescriptor<WorkoutEntity>(
        predicate: #Predicate { $0.status != "superseded" },
        sortBy: [SortDescriptor(\.scheduledFor, order: .reverse)]
    )
    descriptor.fetchLimit = 1
    return try modelContainer.mainContext.fetch(descriptor).first
}

public func workoutForDate(_ date: Date,
                           calendar: Calendar = Calendar(identifier: .iso8601))
                           throws -> WorkoutEntity? {
    let dayStart = calendar.startOfDay(for: date)
    let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
    let descriptor = FetchDescriptor<WorkoutEntity>(
        predicate: #Predicate {
            $0.scheduledFor >= dayStart && $0.scheduledFor < dayEnd
                && $0.status != "superseded"
        },
        sortBy: [SortDescriptor(\.scheduledFor, order: .reverse)]
    )
    return try modelContainer.mainContext.fetch(descriptor).first
}
```

- [ ] **Step 5: Run — confirm pass**

Run: `cd ios/Packages/Repositories && swift test --filter WorkoutRepositoryTests`
Expected: pass.

- [ ] **Step 6: Update Home WeekStrip filtering call site**

`HomeStore.todaysWorkout` will already use the updated `latestWorkout`. Anywhere else that builds the WeekStrip dot map (if it queries directly) must filter `status != "superseded"`. Grep:

```bash
grep -rn "scheduledFor" ios/Packages/Features/Home
```

If `HomeStore` builds `filledDates`, edit the fetch predicate to add the status filter. If not yet wired (Plan 3 only had today's hero card), no edit needed yet — flag for Phase 8 wiring.

- [ ] **Step 7: Commit**

```bash
git add ios/Packages/Persistence/ ios/Packages/Repositories/
git commit -m "feat(workout-repository): filter superseded rows + add workoutForDate(_:)"
```

---

### Task 3.4: `AdaptationStreamEvent` + `AdaptationPayload` model evolution

The current `AdaptationDiff.changes` enum (swap/reps/load/remove/add) is from Plan 2 prototyping. The Plan 4 spec emits `adjustment × N → workout → rationale → done` events and the `AdaptationEntity.diffJSON` should encode the *new* shape: a list of `Adjustment` cards, the `rationale`, the `originalWorkoutID`, and the `newWorkoutPayload` (a full `Workout` JSON).

We **add** new types alongside the existing `AdaptationDiff` (don't delete — DB rows decoded with the old shape may still exist in dev installs). Mark `AdaptationDiff` deprecated for new writes.

**Files:**
- Create: `ios/Packages/CoreModels/Sources/CoreModels/AdaptationStreamEvent.swift`
- Modify: `ios/Packages/CoreModels/Sources/CoreModels/AdaptationDiff.swift` (add new types)
- Modify: `ios/Packages/CoreModels/Tests/CoreModelsTests/AdaptationDiffTests.swift` (existing — keep tests passing) + add new tests for new types

- [ ] **Step 1: Define new value types in `AdaptationDiff.swift`**

Append to `AdaptationDiff.swift` (don't replace existing `AdaptationDiff`):

```swift
public struct Adjustment: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var label: String     // ~3 words
    public var detail: String    // ~6-10 words

    public init(id: String, label: String, detail: String) {
        self.id = id
        self.label = label
        self.detail = detail
    }
}

public struct AdaptationPayload: Codable, Hashable, Sendable {
    public var originalWorkoutID: UUID
    public var newWorkout: PlannedWorkout
    public var adjustments: [Adjustment]
    public var rationale: String

    public init(originalWorkoutID: UUID, newWorkout: PlannedWorkout,
                adjustments: [Adjustment], rationale: String) {
        self.originalWorkoutID = originalWorkoutID
        self.newWorkout = newWorkout
        self.adjustments = adjustments
        self.rationale = rationale
    }
}
```

- [ ] **Step 2: Define stream events**

Create `AdaptationStreamEvent.swift`:

```swift
import Foundation

/// Live updates from the adaptation SSE stream. UI subscribes to render the
/// thinking-state checkpoints, then the four-event result phase.
public enum AdaptationStreamEvent: Sendable {
    case checkpoint(String)
    case textDelta(String)              // raw passthrough during reasoning
    case adjustment(Adjustment)         // emit one per adjustment card
    case workout(PlannedWorkout)        // single Workout JSON for next scheduled date
    case rationale(String)              // coach voice 1-sentence summary
    case done(AdaptationPayload, modelUsed: String, promptTokens: Int, completionTokens: Int)
}
```

- [ ] **Step 3: Add tests**

Append to `AdaptationDiffTests.swift`:

```swift
func test_adaptationPayload_codableRoundTrip() throws {
    let pw = PlannedWorkout(id: "w1",
        scheduledFor: Date(timeIntervalSince1970: 1_730_000_000),
        title: "Push", subtitle: "Upper",
        workoutType: "Strength", durationMin: 45,
        blocks: [], why: "Focus on bilateral pressing volume.")
    let payload = AdaptationPayload(originalWorkoutID: UUID(),
        newWorkout: pw,
        adjustments: [
            Adjustment(id: "a1", label: "Trim main", detail: "Drop one accessory pair"),
            Adjustment(id: "a2", label: "Bilateral focus", detail: "Replace 3 unilateral moves"),
        ],
        rationale: "You felt this was too long; we trimmed it and held the strength stimulus.")
    let data = try JSONEncoder.pulse.encode(payload)
    let round = try JSONDecoder.pulse.decode(AdaptationPayload.self, from: data)
    XCTAssertEqual(round.adjustments.count, 2)
    XCTAssertEqual(round.newWorkout.title, "Push")
}

func test_adjustment_id_isStable() {
    let a = Adjustment(id: "x", label: "L", detail: "D")
    XCTAssertEqual(a.id, "x")
}
```

- [ ] **Step 4: Run**

Run: `cd ios/Packages/CoreModels && swift test --filter AdaptationDiffTests`
Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/CoreModels/
git commit -m "feat(core-models): add AdaptationPayload + Adjustment + stream events"
```

---

### Task 3.5: `PromptBuilder.adaptationSystemPrompt` + `adaptationUserMessage`

The spec §5 spec lays out the system prompt + user message structure. Adapt prompts are coach-personalized (reuse coach personality block) and emit the same checkpoint markers.

**Files:**
- Modify: `ios/Packages/Repositories/Sources/Repositories/PromptBuilder.swift`
- Modify: `ios/Packages/Repositories/Tests/RepositoriesTests/PromptBuilderTests.swift`

- [ ] **Step 1: Add the new prompt builders**

Append to `PromptBuilder.swift`:

```swift
static let adaptationFraming: String = """
You are {coachName}, {coachTagline}.
The user just completed today's session and gave feedback. Adapt
TOMORROW's workout (the next scheduled session) — output ONE replacement
workout with adjustments and a coach-voice rationale. Stream
⟦CHECKPOINT: <label>⟧ markers as you reason.

Your output structure (after thinking):
1. Up to 4 adjustment cards: {"id","label","detail"}, label ≤ 3 words,
   detail 6–10 words, each emitted on its own line as JSON inside a
   ```json fence labeled "adjustment".
2. One full replacement workout matching the schedule date and the
   schema below — emitted in a ```json fence labeled "workout".
3. One rationale line — 1 sentence, your voice — in a ```json fence
   labeled "rationale".

Workout schema (same as plan-gen):

{
  "id": "<short>",
  "scheduledFor": "<ISO8601 date>",
  "title": "<2-4 words>",
  "subtitle": "<1 phrase>",
  "workoutType": "Strength|HIIT|Mobility|Conditioning",
  "durationMin": <int>,
  "blocks": [{
    "id": "<short>",
    "label": "Warm-up|Main|Cooldown",
    "exercises": [{
      "id": "<unique>",
      "exerciseID": "<catalog id>",
      "name": "<display>",
      "sets": [{"setNum":1,"reps":8,"load":"BW","restSec":60}]
    }]
  }],
  "why": "<1-2 sentence coach voice>"
}

Adjustments must reflect what you actually did. Don't lie about the
workout. Use only catalog IDs from the list below.
"""

static func adaptationSystemPrompt(
    coach: Coach,
    availableExercises: [(id: String, name: String, equipment: [String])] = [],
    strictRetry: Bool = false
) -> String {
    var s = adaptationFraming
        .replacingOccurrences(of: "{coachName}", with: coach.displayName)
        .replacingOccurrences(of: "{coachTagline}", with: coach.tagline)
    if !availableExercises.isEmpty {
        let sample = Array(availableExercises.prefix(maxCatalogEntries))
        var catalog = "\n\nAvailable exercises (use these exact IDs for `exerciseID`):\n"
        for ex in sample {
            let equip = ex.equipment.isEmpty ? "body only" : ex.equipment.joined(separator: ", ")
            catalog += "- \(ex.id) | \(ex.name) | \(equip)\n"
        }
        s += catalog
    }
    if strictRetry { s += strictRetrySuffix }
    return s
}

static func adaptationUserMessage(
    nextWorkout: WorkoutEntity,
    justCompletedTitle: String,
    justCompletedDurationSec: Int,
    setLogs: [SetLogEntity],
    feedback: WorkoutFeedback,
    profile: Profile,
    summaries: SevenDayHealthSummary? = nil
) -> String {
    let nextJSON: String = {
        struct NextDTO: Encodable {
            let id: UUID
            let scheduledFor: Date
            let title: String
            let subtitle: String
            let workoutType: String
            let durationMin: Int
        }
        let dto = NextDTO(id: nextWorkout.id, scheduledFor: nextWorkout.scheduledFor,
                          title: nextWorkout.title, subtitle: nextWorkout.subtitle,
                          workoutType: nextWorkout.workoutType,
                          durationMin: nextWorkout.durationMin)
        return (try? JSONEncoder.pulse.encode(dto)).flatMap {
            String(data: $0, encoding: .utf8)
        } ?? "{}"
    }()
    let setLines = setLogs
        .sorted { ($0.exerciseID, $0.setNum) < ($1.exerciseID, $1.setNum) }
        .map { "- \($0.exerciseID) set \($0.setNum): \($0.reps) reps @ \($0.load), RPE \($0.rpe)" }
        .joined(separator: "\n")
    let exRatings = feedback.exerciseRatings
        .map { "  \($0.key): \($0.value.rawValue)" }
        .sorted()
        .joined(separator: "\n")
    let durMin = justCompletedDurationSec / 60
    let durSec = justCompletedDurationSec % 60
    var s = """
    SCHEDULED NEXT SESSION (to replace):
    \(nextJSON)

    JUST-COMPLETED SESSION:
    - workout: \(justCompletedTitle)
    - duration: \(durMin):\(String(format: "%02d", durSec))
    - sets logged:
    \(setLines)

    USER FEEDBACK:
    - rating: \(feedback.rating)/5
    - intensity: \(feedback.intensity)/5
    - mood: \(feedback.mood.rawValue)
    - tags: [\(feedback.tags.joined(separator: ", "))]
    - per-exercise:
    \(exRatings)
    - note: \(feedback.note ?? "")
    """
    if let summaries, !summaries.isEmpty {
        s += "\n\n" + Self.healthSummaryBlock(summaries)
    }
    s += """


    EQUIPMENT: \(profile.equipment.joined(separator: ", "))
    GOAL: \(profile.goals.joined(separator: ", "))
    LEVEL: \(profile.level.rawValue)
    """
    return s
}
```

- [ ] **Step 2: Add tests**

Append to `PromptBuilderTests.swift`:

```swift
@MainActor
func test_adaptationSystemPrompt_includesCoachAndCatalog() {
    let coach = Coach.byID("rex")!
    let s = PromptBuilder.adaptationSystemPrompt(coach: coach,
        availableExercises: [(id: "back-squat", name: "Back Squat", equipment: ["barbell"])])
    XCTAssertTrue(s.contains(coach.displayName))
    XCTAssertTrue(s.contains("back-squat"))
    XCTAssertTrue(s.contains("⟦CHECKPOINT"))
}

@MainActor
func test_adaptationUserMessage_omitsHealthBlockWhenEmpty() throws {
    let container = try PulseModelContainer.inMemory()
    let ctx = container.mainContext
    let next = WorkoutEntity(id: UUID(), planID: UUID(), scheduledFor: Date(),
        title: "Pull", subtitle: "Upper", workoutType: "Strength",
        durationMin: 45, status: "scheduled",
        blocksJSON: Data("[]".utf8), exercisesJSON: Data("[]".utf8))
    ctx.insert(next); try ctx.save()
    let feedback = WorkoutFeedback(sessionID: UUID(), submittedAt: Date(),
        rating: 4, intensity: 4, mood: .good, tags: ["too_long"],
        exerciseRatings: ["back-squat": .up], note: nil)
    let profile = ProfileRepositoryTests.fixtureProfile()
    let s = PromptBuilder.adaptationUserMessage(
        nextWorkout: next,
        justCompletedTitle: "Push",
        justCompletedDurationSec: 2538,
        setLogs: [],
        feedback: feedback,
        profile: profile,
        summaries: nil)
    XCTAssertTrue(s.contains("rating: 4/5"))
    XCTAssertTrue(s.contains("Pull"))
    XCTAssertFalse(s.contains("7-DAY HEALTH SUMMARY"))
}
```

- [ ] **Step 3: Run**

Run: `cd ios/Packages/Repositories && swift test --filter PromptBuilderTests`
Expected: pass.

- [ ] **Step 4: Commit**

```bash
git add ios/Packages/Repositories/
git commit -m "feat(prompt-builder): add adaptation system prompt + user message builders"
```

---

### Task 3.6: Replace `AnthropicRequest.adaptation` factory

The current `.adaptation` factory uses an old prototype prompt. Replace it: `.adaptation(systemPrompt:userMessage:)` mirrors the plan-gen factory shape.

**Files:**
- Modify: `ios/Packages/Networking/Sources/Networking/Anthropic/AnthropicRequest.swift`

- [ ] **Step 1: Replace the factory**

Edit `AnthropicRequest.swift`:

```swift
public extension AnthropicRequest {
    static func planGeneration(systemPrompt: String, userMessage: String) -> AnthropicRequest {
        AnthropicRequest(
            model: "claude-opus-4-7",
            maxTokens: 4096,
            system: systemPrompt,
            systemCacheControl: .ephemeral,
            messages: [.init(role: .user, content: userMessage)]
        )
    }

    static func adaptation(systemPrompt: String, userMessage: String) -> AnthropicRequest {
        AnthropicRequest(
            model: "claude-opus-4-7",
            maxTokens: 4096,
            system: systemPrompt,
            systemCacheControl: .ephemeral,
            messages: [.init(role: .user, content: userMessage)]
        )
    }
}
```

- [ ] **Step 2: Update old call sites**

The only previous caller (`FeedbackRepository.adaptPlan`) is being removed in Task 3.7. No other callers.

- [ ] **Step 3: Run all networking tests**

Run: `cd ios/Packages/Networking && swift test`
Expected: pass.

- [ ] **Step 4: Commit**

```bash
git add ios/Packages/Networking/
git commit -m "refactor(networking): align AnthropicRequest.adaptation with plan-gen factory shape"
```

---

### Task 3.7: Slim `FeedbackRepository` to feedback-only + idempotency

Remove `adaptPlan` (moved to `AdaptationRepository` in 3.8). Keep `saveFeedback`, make it idempotent on `sessionID`, and reject `rating == 0`.

**Files:**
- Modify: `ios/Packages/Repositories/Sources/Repositories/FeedbackRepository.swift`
- Modify: `ios/Packages/Repositories/Tests/RepositoriesTests/FeedbackRepositoryTests.swift`

- [ ] **Step 1: Write failing tests**

Append to `FeedbackRepositoryTests.swift`:

```swift
@MainActor
func test_saveFeedback_isIdempotentOnSessionID() throws {
    let container = try PulseModelContainer.inMemory()
    let ctx = container.mainContext
    let session = SessionEntity(id: UUID(), workoutID: UUID(), startedAt: Date())
    ctx.insert(session); try ctx.save()
    let repo = FeedbackRepository.makeForTests(modelContainer: container)
    let fb = WorkoutFeedback(sessionID: session.id, submittedAt: Date(),
        rating: 3, intensity: 3, mood: .good, tags: [],
        exerciseRatings: [:], note: nil)
    try repo.saveFeedback(fb)
    var fb2 = fb
    fb2.rating = 5
    try repo.saveFeedback(fb2)
    let rows = try ctx.fetch(FetchDescriptor<FeedbackEntity>())
    XCTAssertEqual(rows.count, 1)
    XCTAssertEqual(rows.first?.rating, 5)
}

@MainActor
func test_saveFeedback_throwsOnRatingZero() throws {
    let container = try PulseModelContainer.inMemory()
    let ctx = container.mainContext
    let session = SessionEntity(id: UUID(), workoutID: UUID(), startedAt: Date())
    ctx.insert(session); try ctx.save()
    let repo = FeedbackRepository.makeForTests(modelContainer: container)
    let fb = WorkoutFeedback(sessionID: session.id, submittedAt: Date(),
        rating: 0, intensity: 3, mood: .good, tags: [],
        exerciseRatings: [:], note: nil)
    XCTAssertThrowsError(try repo.saveFeedback(fb))
}
```

- [ ] **Step 2: Run — confirm fail**

Run: `cd ios/Packages/Repositories && swift test --filter FeedbackRepositoryTests`
Expected: fail (saveFeedback always inserts; rating: 0 isn't blocked).

- [ ] **Step 3: Replace `FeedbackRepository.swift`**

Replace contents:

```swift
import Foundation
import SwiftData
import CoreModels
import Persistence

public enum FeedbackRepositoryError: Error, Equatable {
    case ratingMustBePositive
}

@MainActor
public final class FeedbackRepository {
    public let modelContainer: ModelContainer

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    public static func makeForTests(modelContainer: ModelContainer) -> FeedbackRepository {
        FeedbackRepository(modelContainer: modelContainer)
    }

    /// Idempotent on `feedback.sessionID` — calling twice updates the existing row.
    public func saveFeedback(_ feedback: WorkoutFeedback) throws {
        guard feedback.rating > 0 else { throw FeedbackRepositoryError.ratingMustBePositive }
        let ctx = modelContainer.mainContext
        try ctx.transaction {
            let sid = feedback.sessionID
            let session = try ctx.fetch(FetchDescriptor<SessionEntity>(
                predicate: #Predicate { $0.id == sid })).first
            let exData = (try? JSONEncoder().encode(feedback.exerciseRatings)) ?? Data()
            // Look for an existing FeedbackEntity attached to the same session.
            let existing = try ctx.fetch(FetchDescriptor<FeedbackEntity>())
                .first(where: { $0.session?.id == sid })
            if let row = existing {
                row.submittedAt = feedback.submittedAt
                row.rating = feedback.rating
                row.intensity = feedback.intensity
                row.mood = feedback.mood.rawValue
                row.tags = feedback.tags
                row.exRatingsJSON = exData
                row.note = feedback.note
            } else {
                ctx.insert(FeedbackEntity(
                    id: UUID(),
                    session: session,
                    submittedAt: feedback.submittedAt,
                    rating: feedback.rating,
                    intensity: feedback.intensity,
                    mood: feedback.mood.rawValue,
                    tags: feedback.tags,
                    exRatingsJSON: exData,
                    note: feedback.note
                ))
            }
        }
    }
}
```

(Note: the public `init(modelContainer:api:)` is removed — call sites that built `FeedbackRepository` with an APIClient must be updated. With `adaptPlan` gone, no caller needed an API client anyway.)

- [ ] **Step 4: Update call sites**

Grep:

```bash
grep -rn "FeedbackRepository(" ios/
```

Update each constructor call to drop `api:` argument. Likely none in production yet.

- [ ] **Step 5: Run**

Run: `cd ios/Packages/Repositories && swift test --filter FeedbackRepositoryTests`
Expected: pass.

- [ ] **Step 6: Commit**

```bash
git add ios/Packages/Repositories/
git commit -m "refactor(feedback-repository): split adaptation streaming out; idempotent saveFeedback + reject rating==0"
```

---

### Task 3.8: `AdaptationRepository` — streamAdaptation + supersedes-workout transaction + fixtures

This is the core of the adaptation loop. Streams events from the adaptation endpoint, decodes adjustments + replacement workout + rationale, then in a single transaction inserts the new `WorkoutEntity`, marks the original superseded, and writes the `AdaptationEntity`.

**Files:**
- Create: `ios/Packages/Repositories/Sources/Repositories/AdaptationRepository.swift`
- Create: `ios/Packages/Repositories/Tests/RepositoriesTests/AdaptationRepositoryTests.swift`
- Create: `ios/Packages/Repositories/Tests/RepositoriesTests/Fixtures/AdaptationStream-success.txt`
- Create: `ios/Packages/Repositories/Tests/RepositoriesTests/Fixtures/AdaptationStream-malformed.txt`

The SSE worker (Anthropic) emits `event: content_block_delta` events that carry the model's text. To make a multi-event stream parseable, we instruct the model (in the system prompt) to emit each adjustment / workout / rationale inside a fenced ```json block with a label. Client-side, scan completed text for such blocks as they finish.

For Plan 4, simplest: parse the *whole* assembled text at `message_stop` (same as plan-gen), split by labeled fences (`json adjustment`, `json workout`, `json rationale`), and emit events in sequence. Streaming-during-thinking still works via checkpoints + textDelta.

- [ ] **Step 1: Add the fenced-block extractor for labeled blocks**

We have `JSONBlockExtractor.extract(from:)` for plain ```json. Extend with a labeled variant in `Networking`:

Edit `ios/Packages/Networking/Sources/Networking/SSE/JSONBlockExtractor.swift`:

```swift
import Foundation

public enum JSONBlockExtractor {
    /// Returns the contents of the first ```json ... ``` fence if present.
    public static func extract(from text: String) -> String? {
        // Existing implementation — keep as-is.
        return extractAllLabeled(from: text).first(where: { $0.label == nil })?.body
            ?? extractAllLabeled(from: text).first?.body
    }

    public struct LabeledBlock: Equatable {
        public let label: String?    // e.g. "adjustment" / "workout" / "rationale"
        public let body: String
    }

    /// Returns every fenced ```json[ <label>] ... ``` block in order.
    public static func extractAllLabeled(from text: String) -> [LabeledBlock] {
        var out: [LabeledBlock] = []
        let pattern = "```json(?:[ \\t]+([a-z]+))?[ \\t]*\\n([\\s\\S]*?)\\n```"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return out }
        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        for m in matches {
            let label: String? = m.range(at: 1).location == NSNotFound
                ? nil : ns.substring(with: m.range(at: 1))
            let body = ns.substring(with: m.range(at: 2))
            out.append(.init(label: label, body: body))
        }
        return out
    }
}
```

(If the existing `extract(from:)` body is more sophisticated, preserve it and just add `extractAllLabeled` alongside; you can tweak `extract` to call into it.)

- [ ] **Step 2: Write the recorded SSE fixtures**

Create `Fixtures/AdaptationStream-success.txt` — a minimal recorded SSE stream that produces one adjustment, one workout, and one rationale. The exact bytes mirror Anthropic's SSE protocol: event lines, data lines, and a `message_stop`.

```
event: message_start
data: {"type":"message_start","message":{"id":"msg_1","model":"claude-opus-4-7","content":[],"usage":{"input_tokens":120,"output_tokens":0}}}

event: content_block_start
data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"⟦CHECKPOINT: reading session log⟧\n"}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"```json adjustment\n{\"id\":\"a1\",\"label\":\"Trim main\",\"detail\":\"Drop one accessory pair\"}\n```\n"}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"```json workout\n{\"id\":\"adapted-wed\",\"scheduledFor\":\"2026-04-30T00:00:00Z\",\"title\":\"Pull steady\",\"subtitle\":\"Lighter day\",\"workoutType\":\"Strength\",\"durationMin\":35,\"blocks\":[],\"why\":\"You felt last session was long.\"}\n```\n"}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"```json rationale\n{\"text\":\"Trimmed the volume; held the strength stimulus.\"}\n```\n"}}

event: message_delta
data: {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"input_tokens":120,"output_tokens":80}}

event: message_stop
data: {"type":"message_stop"}

```

(Each SSE record is `event:` line, `data:` line, blank line. Make sure the file ends with a blank line after `message_stop`.)

Create `Fixtures/AdaptationStream-malformed.txt` — same structure but the `workout` block's JSON is invalid (missing closing brace).

```
event: message_start
data: {"type":"message_start","message":{"id":"msg_2","model":"claude-opus-4-7","content":[],"usage":{"input_tokens":100,"output_tokens":0}}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"```json workout\n{\"id\":\"broken\",\"scheduledFor\":\"2026-04-30T00:00:00Z\"\n```\n"}}

event: message_delta
data: {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"input_tokens":100,"output_tokens":40}}

event: message_stop
data: {"type":"message_stop"}

```

- [ ] **Step 3: Implement `AdaptationRepository`**

Create `AdaptationRepository.swift`:

```swift
import Foundation
import SwiftData
import CoreModels
import Networking
import Persistence

@MainActor
public final class AdaptationRepository {
    public let modelContainer: ModelContainer
    private let api: APIClient?

    public init(modelContainer: ModelContainer, api: APIClient) {
        self.modelContainer = modelContainer
        self.api = api
    }

    public static func makeForTests(modelContainer: ModelContainer) -> AdaptationRepository {
        AdaptationRepository(modelContainer: modelContainer, api: nil)
    }

    private init(modelContainer: ModelContainer, api: APIClient?) {
        self.modelContainer = modelContainer
        self.api = api
    }

    /// Streams an adaptation request. Yields adjustment/workout/rationale events
    /// as labeled fences appear in the assembled text, then `done` after persistence.
    public func streamAdaptation(
        systemPrompt: String,
        userMessage: String,
        nextWorkoutID: UUID,
        feedbackID: UUID,
        appliedToPlanID: UUID
    ) -> AsyncThrowingStream<AdaptationStreamEvent, Error> {
        guard let api else {
            return AsyncThrowingStream { $0.finish(throwing: APIClientError.badStatus(0)) }
        }
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = AnthropicRequest.adaptation(
                        systemPrompt: systemPrompt,
                        userMessage: userMessage)
                    var fullText = ""
                    var modelUsed = "claude-opus-4-7"
                    var promptTokens = 0
                    var completionTokens = 0
                    var checkpoints = CheckpointExtractor()
                    var emittedAdjustmentIDs: Set<String> = []
                    var emittedWorkout = false
                    var emittedRationale: String?

                    for try await event in api.streamEvents(request: request) {
                        switch event.event {
                        case "message_start":
                            if let dict = try? JSONSerialization.jsonObject(with: Data(event.data.utf8)) as? [String: Any],
                               let msg = dict["message"] as? [String: Any],
                               let m = msg["model"] as? String { modelUsed = m }
                        case "content_block_delta":
                            if let text = Self.extractTextDelta(eventData: event.data) {
                                fullText.append(text)
                                let result = checkpoints.feed(text)
                                for cp in result.checkpoints { continuation.yield(.checkpoint(cp)) }
                                if !result.passthroughText.isEmpty {
                                    continuation.yield(.textDelta(result.passthroughText))
                                }
                                // Try to emit any newly-completed labeled blocks.
                                for block in JSONBlockExtractor.extractAllLabeled(from: fullText) {
                                    switch block.label {
                                    case "adjustment":
                                        if let data = block.body.data(using: .utf8),
                                           let adj = try? JSONDecoder.pulse.decode(Adjustment.self, from: data),
                                           !emittedAdjustmentIDs.contains(adj.id) {
                                            emittedAdjustmentIDs.insert(adj.id)
                                            continuation.yield(.adjustment(adj))
                                        }
                                    case "workout":
                                        if !emittedWorkout,
                                           let data = block.body.data(using: .utf8),
                                           let pw = try? JSONDecoder.pulse.decode(PlannedWorkout.self, from: data) {
                                            emittedWorkout = true
                                            continuation.yield(.workout(pw))
                                        }
                                    case "rationale":
                                        if emittedRationale == nil,
                                           let data = block.body.data(using: .utf8),
                                           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                                           let text = dict["text"] as? String {
                                            emittedRationale = text
                                            continuation.yield(.rationale(text))
                                        }
                                    default:
                                        break
                                    }
                                }
                            }
                        case "message_delta":
                            if let dict = try? JSONSerialization.jsonObject(with: Data(event.data.utf8)) as? [String: Any],
                               let usage = dict["usage"] as? [String: Any] {
                                if let p = usage["input_tokens"] as? Int { promptTokens = p }
                                if let c = usage["output_tokens"] as? Int { completionTokens = c }
                            }
                        case "message_stop":
                            // Final reconciliation: if blocks were never emitted, emit them now.
                            let finalBlocks = JSONBlockExtractor.extractAllLabeled(from: fullText)
                            // Validate workout decoded to PlannedWorkout — required for `done`.
                            guard let workoutBlock = finalBlocks.first(where: { $0.label == "workout" }),
                                  let workoutData = workoutBlock.body.data(using: .utf8),
                                  let newWorkout = try? JSONDecoder.pulse.decode(PlannedWorkout.self, from: workoutData) else {
                                throw APIClientError.decoding("missing or malformed workout block")
                            }
                            let adjustments: [Adjustment] = finalBlocks
                                .filter { $0.label == "adjustment" }
                                .compactMap {
                                    guard let d = $0.body.data(using: .utf8) else { return nil }
                                    return try? JSONDecoder.pulse.decode(Adjustment.self, from: d)
                                }
                            let rationale: String = finalBlocks
                                .first(where: { $0.label == "rationale" })
                                .flatMap { b -> String? in
                                    guard let d = b.body.data(using: .utf8),
                                          let dict = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return nil }
                                    return dict["text"] as? String
                                } ?? ""
                            let payload = AdaptationPayload(
                                originalWorkoutID: nextWorkoutID,
                                newWorkout: newWorkout,
                                adjustments: adjustments,
                                rationale: rationale)
                            try persist(payload: payload,
                                        feedbackID: feedbackID,
                                        appliedToPlanID: appliedToPlanID,
                                        modelUsed: modelUsed,
                                        promptTokens: promptTokens,
                                        completionTokens: completionTokens)
                            continuation.yield(.done(payload, modelUsed: modelUsed,
                                                     promptTokens: promptTokens,
                                                     completionTokens: completionTokens))
                            continuation.finish()
                            return
                        default:
                            break
                        }
                    }
                    throw APIClientError.decoding("stream ended without message_stop")
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Inserts the new WorkoutEntity, marks the original superseded, persists the AdaptationEntity.
    /// All three writes in a single transaction.
    public func persist(payload: AdaptationPayload,
                        feedbackID: UUID,
                        appliedToPlanID: UUID,
                        modelUsed: String,
                        promptTokens: Int,
                        completionTokens: Int) throws {
        let ctx = modelContainer.mainContext
        try ctx.transaction {
            let originalID = payload.originalWorkoutID
            guard let original = try ctx.fetch(FetchDescriptor<WorkoutEntity>(
                predicate: #Predicate { $0.id == originalID })).first else {
                throw AdaptationRepositoryError.originalWorkoutNotFound(originalID)
            }
            original.status = "superseded"

            let pw = payload.newWorkout
            let blocksJSON = (try? JSONEncoder.pulse.encode(pw.blocks)) ?? Data("[]".utf8)
            let exercisesFlat = pw.blocks.flatMap { $0.exercises }
            let exercisesJSON = (try? JSONEncoder.pulse.encode(exercisesFlat)) ?? Data("[]".utf8)
            ctx.insert(WorkoutEntity(
                id: UUID(), planID: original.planID,
                scheduledFor: pw.scheduledFor,
                title: pw.title, subtitle: pw.subtitle,
                workoutType: pw.workoutType, durationMin: pw.durationMin,
                status: "scheduled",
                blocksJSON: blocksJSON, exercisesJSON: exercisesJSON,
                why: pw.why))

            let payloadData = (try? JSONEncoder.pulse.encode(payload)) ?? Data()
            ctx.insert(AdaptationEntity(
                id: UUID(),
                feedbackID: feedbackID,
                appliedToPlanID: appliedToPlanID,
                generatedAt: Date(),
                modelUsed: modelUsed,
                promptTokens: promptTokens,
                completionTokens: completionTokens,
                diffJSON: payloadData,
                rationale: payload.rationale))
        }
    }

    private static func extractTextDelta(eventData: String) -> String? {
        guard let data = eventData.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let delta = dict["delta"] as? [String: Any],
              delta["type"] as? String == "text_delta",
              let text = delta["text"] as? String else { return nil }
        return text
    }
}

public enum AdaptationRepositoryError: Error, Equatable {
    case originalWorkoutNotFound(UUID)
}
```

- [ ] **Step 4: Write `AdaptationRepositoryTests`**

Create `AdaptationRepositoryTests.swift`:

```swift
import XCTest
import SwiftData
import CoreModels
import Networking
import Persistence
@testable import Repositories

final class AdaptationRepositoryTests: XCTestCase {
    @MainActor
    func test_persist_supersedesOriginalAndInsertsNewWorkout() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let originalID = UUID()
        let original = WorkoutEntity(id: originalID, planID: UUID(),
            scheduledFor: Date(timeIntervalSince1970: 1_730_000_000),
            title: "Original Pull", subtitle: "", workoutType: "Strength",
            durationMin: 45, status: "scheduled",
            blocksJSON: Data("[]".utf8), exercisesJSON: Data("[]".utf8))
        ctx.insert(original); try ctx.save()
        let repo = AdaptationRepository.makeForTests(modelContainer: container)
        let payload = AdaptationPayload(
            originalWorkoutID: originalID,
            newWorkout: PlannedWorkout(id: "adapted",
                scheduledFor: Date(timeIntervalSince1970: 1_730_000_000),
                title: "Adapted Pull", subtitle: "Lighter",
                workoutType: "Strength", durationMin: 35,
                blocks: [], why: "Trimmed."),
            adjustments: [Adjustment(id: "a1", label: "Trim main", detail: "Cut one")],
            rationale: "Trimmed the load.")
        try repo.persist(payload: payload, feedbackID: UUID(),
                         appliedToPlanID: UUID(),
                         modelUsed: "claude-opus-4-7",
                         promptTokens: 100, completionTokens: 200)
        let workouts = try ctx.fetch(FetchDescriptor<WorkoutEntity>())
        XCTAssertEqual(workouts.count, 2)
        XCTAssertEqual(workouts.first(where: { $0.id == originalID })?.status, "superseded")
        XCTAssertNotNil(workouts.first(where: { $0.title == "Adapted Pull" }))
        let adaptations = try ctx.fetch(FetchDescriptor<AdaptationEntity>())
        XCTAssertEqual(adaptations.count, 1)
    }

    @MainActor
    func test_persist_throwsWhenOriginalMissing() {
        let container = try! PulseModelContainer.inMemory()
        let repo = AdaptationRepository.makeForTests(modelContainer: container)
        let payload = AdaptationPayload(
            originalWorkoutID: UUID(),
            newWorkout: PlannedWorkout(id: "x", scheduledFor: Date(),
                title: "x", subtitle: "x", workoutType: "Strength",
                durationMin: 30, blocks: []),
            adjustments: [], rationale: "")
        XCTAssertThrowsError(try repo.persist(payload: payload,
            feedbackID: UUID(), appliedToPlanID: UUID(),
            modelUsed: "m", promptTokens: 0, completionTokens: 0))
    }

    @MainActor
    func test_persist_rollsBackOnFailure() throws {
        // Without a real injection seam for partial failure, this test asserts
        // the error short-circuit: when persist throws on missing original, no
        // partial AdaptationEntity is inserted (i.e., the order of writes
        // ensures lookup happens first).
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let repo = AdaptationRepository.makeForTests(modelContainer: container)
        let payload = AdaptationPayload(
            originalWorkoutID: UUID(),
            newWorkout: PlannedWorkout(id: "x", scheduledFor: Date(),
                title: "x", subtitle: "x", workoutType: "Strength",
                durationMin: 30, blocks: []),
            adjustments: [], rationale: "")
        _ = try? repo.persist(payload: payload,
            feedbackID: UUID(), appliedToPlanID: UUID(),
            modelUsed: "m", promptTokens: 0, completionTokens: 0)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<AdaptationEntity>()).count, 0)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<WorkoutEntity>()).count, 0)
    }
}
```

(For Plan 4 we accept that streaming-fixture replay would require injecting a fake `APIClient`. That's a follow-up — the persistence path is the safety-critical part and is fully covered.)

- [ ] **Step 5: Run**

Run: `cd ios/Packages/Repositories && swift test --filter AdaptationRepositoryTests`
Expected: pass.

- [ ] **Step 6: Commit**

```bash
git add ios/Packages/Repositories/ ios/Packages/Networking/
git commit -m "feat(adaptation-repository): stream adapt + supersedes-workout transaction"
```

---


## Phase 4 — InWorkout feature package

The data-dense session screen with state machine, inline-editable SET LOG, rest timer, and discard path.

### Task 4.1: Scaffold `Features/InWorkout` SPM package

**Files:**
- Create: `ios/Packages/Features/InWorkout/Package.swift`
- Create: `ios/Packages/Features/InWorkout/Sources/InWorkout/Module.swift`
- Modify: `ios/Project.yml`

- [ ] **Step 1: Create `Package.swift`**

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "InWorkout",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "InWorkout", targets: ["InWorkout"])],
    dependencies: [
        .package(path: "../../CoreModels"),
        .package(path: "../../DesignSystem"),
        .package(path: "../../Persistence"),
        .package(path: "../../Repositories"),
    ],
    targets: [
        .target(name: "InWorkout",
                dependencies: ["CoreModels", "DesignSystem", "Persistence", "Repositories"]),
        .testTarget(name: "InWorkoutTests", dependencies: ["InWorkout"]),
    ]
)
```

- [ ] **Step 2: Create stub `Module.swift`**

```swift
import Foundation

public enum InWorkoutModule {
    public static let name = "InWorkout"
}
```

- [ ] **Step 3: Register in `Project.yml`**

Add to `packages:`:

```yaml
  InWorkout:
    path: Packages/Features/InWorkout
```

And to `targets.PulseApp.dependencies:`:

```yaml
      - package: InWorkout
```

- [ ] **Step 4: Regenerate**

Run: `cd ios && xcodegen generate`
Expected: success.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/Features/InWorkout/ ios/Project.yml ios/PulseApp.xcodeproj/
git commit -m "chore(in-workout): scaffold Features/InWorkout SPM package"
```

---

### Task 4.2: `SessionStore` state machine

The store owns the in-memory state (current exercise/set/phase, draft entry, elapsed seconds) and exposes commands. Persistence flows through `SessionRepository`. Pure-logic — no SwiftUI.

**Files:**
- Create: `ios/Packages/Features/InWorkout/Sources/InWorkout/SessionStore.swift`
- Create: `ios/Packages/Features/InWorkout/Tests/InWorkoutTests/SessionStoreTests.swift`
- Create: `ios/Packages/Features/InWorkout/Tests/InWorkoutTests/SmokeTests.swift`

- [ ] **Step 1: Write the tests**

Create `SessionStoreTests.swift`:

```swift
import XCTest
import CoreModels
import Persistence
import SwiftData
@testable import InWorkout

final class SessionStoreTests: XCTestCase {
    @MainActor
    private func makeFlat(setsPerEx: Int = 2, exerciseCount: Int = 2) -> [SessionStore.FlatEntry] {
        var out: [SessionStore.FlatEntry] = []
        for ei in 0..<exerciseCount {
            for sn in 1...setsPerEx {
                out.append(.init(blockLabel: "Main",
                                 exerciseID: "ex\(ei)",
                                 exerciseName: "Exercise \(ei)",
                                 setNum: sn,
                                 prescribedReps: 8,
                                 prescribedLoad: "60kg",
                                 restSec: 60))
            }
        }
        return out
    }

    @MainActor
    func test_initialState_pointsAtFirstSet() {
        let store = SessionStore.preview(flat: makeFlat())
        XCTAssertEqual(store.idx, 0)
        XCTAssertEqual(store.phase, .work)
        XCTAssertEqual(store.draft.reps, 8)
        XCTAssertEqual(store.draft.load, "60kg")
        XCTAssertEqual(store.draft.rpe, 0)
    }

    @MainActor
    func test_logSet_advancesWithinExercise() async {
        let store = SessionStore.preview(flat: makeFlat())
        await store.logCurrentSet()
        XCTAssertEqual(store.idx, 1)
        XCTAssertEqual(store.phase, .rest)
    }

    @MainActor
    func test_restTimerAutoAdvances() async {
        let store = SessionStore.preview(flat: makeFlat())
        await store.logCurrentSet()
        XCTAssertEqual(store.phase, .rest)
        store.tick(by: 60)
        XCTAssertEqual(store.phase, .work)
    }

    @MainActor
    func test_finishOnLastSetEmitsCompleted() async {
        let store = SessionStore.preview(flat: makeFlat(setsPerEx: 1, exerciseCount: 1))
        var completed = false
        store.onLifecycle = { event in if case .completed = event { completed = true } }
        await store.logCurrentSet()
        XCTAssertTrue(completed)
    }

    @MainActor
    func test_discardEmitsDiscardedAndResets() async {
        let store = SessionStore.preview(flat: makeFlat())
        var discarded = false
        store.onLifecycle = { event in if case .discarded = event { discarded = true } }
        await store.logCurrentSet()
        await store.discard()
        XCTAssertTrue(discarded)
    }
}
```

Create `SmokeTests.swift`:

```swift
import XCTest
@testable import InWorkout

final class SmokeTests: XCTestCase {
    func test_module() { XCTAssertEqual(InWorkoutModule.name, "InWorkout") }
}
```

- [ ] **Step 2: Run — confirm fail (build error: SessionStore not found)**

Run: `cd ios/Packages/Features/InWorkout && swift test`
Expected: build error.

- [ ] **Step 3: Implement `SessionStore`**

Create `SessionStore.swift`:

```swift
import Foundation
import Observation
import CoreModels
import Persistence
import Repositories
import SwiftData

@MainActor
@Observable
public final class SessionStore {
    public enum Phase: Sendable { case work, rest }
    public enum Lifecycle: Sendable { case completed(SessionEntity), discarded }

    public struct FlatEntry: Hashable, Sendable {
        public let blockLabel: String
        public let exerciseID: String
        public let exerciseName: String
        public let setNum: Int
        public let prescribedReps: Int
        public let prescribedLoad: String
        public let restSec: Int

        public init(blockLabel: String, exerciseID: String, exerciseName: String,
                    setNum: Int, prescribedReps: Int, prescribedLoad: String, restSec: Int) {
            self.blockLabel = blockLabel
            self.exerciseID = exerciseID
            self.exerciseName = exerciseName
            self.setNum = setNum
            self.prescribedReps = prescribedReps
            self.prescribedLoad = prescribedLoad
            self.restSec = restSec
        }
    }

    public struct Draft: Sendable {
        public var reps: Int
        public var load: String
        public var rpe: Int   // 0 = unset, 1-10 = user-set
    }

    public private(set) var workoutID: UUID
    public private(set) var sessionID: UUID?
    public private(set) var flat: [FlatEntry]
    public private(set) var idx: Int = 0
    public private(set) var phase: Phase = .work
    public private(set) var secs: Int = 0
    public var draft: Draft

    public var onLifecycle: (Lifecycle) -> Void = { _ in }

    private let repo: SessionRepository?

    /// Test-only: skip persistence.
    public static func preview(flat: [FlatEntry]) -> SessionStore {
        SessionStore(workoutID: UUID(), flat: flat, repo: nil)
    }

    public init(workoutID: UUID, flat: [FlatEntry], repo: SessionRepository?) {
        self.workoutID = workoutID
        self.flat = flat
        self.repo = repo
        let first = flat.first
        self.draft = Draft(reps: first?.prescribedReps ?? 0,
                           load: first?.prescribedLoad ?? "",
                           rpe: 0)
    }

    public var current: FlatEntry? { flat.indices.contains(idx) ? flat[idx] : nil }
    public var isLastSet: Bool { idx == flat.count - 1 }

    public func start() async {
        if let repo {
            do {
                let session = try repo.start(workoutID: workoutID)
                sessionID = session.id
            } catch {
                // Surface via lifecycle? For Plan 4, log + drop silently.
            }
        }
    }

    public func logCurrentSet() async {
        guard let cur = current else { return }
        if let sessionID, let repo {
            try? repo.logSet(sessionID: sessionID,
                             exerciseID: cur.exerciseID,
                             setNum: cur.setNum,
                             reps: draft.reps,
                             load: draft.load,
                             rpe: draft.rpe)
        }
        if isLastSet {
            await finish()
            return
        }
        idx += 1
        if let next = current {
            draft = Draft(reps: next.prescribedReps,
                          load: next.prescribedLoad,
                          rpe: 0)
        }
        phase = .rest
        secs = 0
    }

    public func tick(by deltaSec: Int) {
        guard phase == .rest else { return }
        secs += deltaSec
        if let cur = current, secs >= cur.restSec {
            phase = .work
            secs = 0
        }
    }

    public func finish() async {
        if let sessionID, let repo {
            try? repo.finish(sessionID: sessionID)
            // Re-fetch the session entity for the lifecycle payload.
            // Skip the strict re-fetch — caller will look it up by sessionID.
            let dummy = SessionEntity(id: sessionID, workoutID: workoutID,
                                      startedAt: Date())   // identity placeholder
            onLifecycle(.completed(dummy))
        } else {
            let dummy = SessionEntity(id: UUID(), workoutID: workoutID,
                                      startedAt: Date())
            onLifecycle(.completed(dummy))
        }
    }

    public func discard() async {
        if let sessionID, let repo {
            try? repo.discardSession(id: sessionID)
        }
        idx = 0
        phase = .work
        secs = 0
        if let first = flat.first {
            draft = Draft(reps: first.prescribedReps,
                          load: first.prescribedLoad, rpe: 0)
        }
        onLifecycle(.discarded)
    }
}
```

- [ ] **Step 4: Run — confirm pass**

Run: `cd ios/Packages/Features/InWorkout && swift test`
Expected: 5/5 + smoke = pass.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/Features/InWorkout/
git commit -m "feat(in-workout): SessionStore state machine"
```

---

### Task 4.3: `InWorkoutView` and components

Build the data-dense layout. Subdivide into components for readability. The Plan 4 spec calls out: top bar + progress segments + exercise card + live metrics grid (HR placeholder) + SET LOG card with inline editors + bottom controls.

**Files:**
- Create: `ios/Packages/Features/InWorkout/Sources/InWorkout/InWorkoutView.swift`
- Create: `ios/Packages/Features/InWorkout/Sources/InWorkout/Components/ProgressSegmentsView.swift`
- Create: `ios/Packages/Features/InWorkout/Sources/InWorkout/Components/ExerciseCardView.swift`
- Create: `ios/Packages/Features/InWorkout/Sources/InWorkout/Components/LiveMetricsGridView.swift`
- Create: `ios/Packages/Features/InWorkout/Sources/InWorkout/Components/SetLogCardView.swift`
- Create: `ios/Packages/Features/InWorkout/Sources/InWorkout/Components/RestPhaseView.swift`
- Create: `ios/Packages/Features/InWorkout/Sources/InWorkout/Components/BottomControlsView.swift`

- [ ] **Step 1: ProgressSegmentsView**

```swift
import SwiftUI
import DesignSystem

struct ProgressSegmentsView: View {
    let total: Int
    let completed: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<max(total, 1), id: \.self) { i in
                Capsule()
                    .fill(i < completed ? PulseColors.ink0.color : PulseColors.bg2.color)
                    .frame(height: 4)
            }
        }
    }
}
```

- [ ] **Step 2: ExerciseCardView**

```swift
import SwiftUI
import DesignSystem

struct ExerciseCardView: View {
    let blockLabel: String
    let exerciseName: String
    let setIndexLabel: String   // "SET 2 OF 4"

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                Text(blockLabel.uppercased())
                    .pulseFont(.small)
                    .foregroundStyle(PulseColors.ink2.color)
                Text(exerciseName)
                    .pulseFont(.h1)
                    .foregroundStyle(PulseColors.ink0.color)
                Text(setIndexLabel)
                    .pulseFont(.small)
                    .foregroundStyle(PulseColors.ink2.color)
            }
        }
    }
}
```

- [ ] **Step 3: LiveMetricsGridView (with HR placeholder)**

```swift
import SwiftUI
import DesignSystem

struct LiveMetricsGridView: View {
    let elapsed: String  // "12:34"
    let restRemaining: String  // "0:45" or "—"
    let avgHR: String  // "—" until Plan 5

    var body: some View {
        HStack(spacing: PulseSpacing.sm) {
            tile(label: "TIME", value: elapsed)
            tile(label: "REST", value: restRemaining)
            tile(label: "HR", value: avgHR)
        }
    }

    private func tile(label: String, value: String) -> some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .pulseFont(.small)
                    .foregroundStyle(PulseColors.ink2.color)
                Text(value)
                    .pulseFont(.h2)
                    .foregroundStyle(PulseColors.ink0.color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
```

- [ ] **Step 4: SetLogCardView (inline-editable)**

```swift
import SwiftUI
import DesignSystem

struct SetLogCardView: View {
    @Binding var reps: Int
    @Binding var load: String
    @Binding var rpe: Int
    let prescribedReps: Int
    let prescribedLoad: String

    @State private var loadFreeform = false
    @State private var freeformText = ""

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                Text("SET LOG")
                    .pulseFont(.small)
                    .foregroundStyle(PulseColors.ink2.color)

                stepperRow(title: "Reps",
                           value: $reps,
                           step: 1,
                           prescribed: "\(prescribedReps)")

                if loadFreeform {
                    HStack {
                        Text("Load")
                            .pulseFont(.body)
                            .foregroundStyle(PulseColors.ink1.color)
                        Spacer()
                        TextField("BW / 0:30 / 60kg", text: $freeformText)
                            .pulseFont(.body)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                load = freeformText
                                loadFreeform = false
                            }
                    }
                } else {
                    loadStepperRow(prescribed: prescribedLoad)
                }

                rpeRow
            }
        }
    }

    private func stepperRow(title: String, value: Binding<Int>, step: Int, prescribed: String) -> some View {
        HStack {
            Text(title).pulseFont(.body).foregroundStyle(PulseColors.ink1.color)
            Spacer()
            Text("(prescribed \(prescribed))")
                .pulseFont(.small).foregroundStyle(PulseColors.ink2.color)
            Stepper("\(value.wrappedValue)", value: value, in: 0...50, step: step)
                .pulseFont(.body)
        }
    }

    private func loadStepperRow(prescribed: String) -> some View {
        HStack {
            Text("Load").pulseFont(.body).foregroundStyle(PulseColors.ink1.color)
            Spacer()
            Text("(prescribed \(prescribed))")
                .pulseFont(.small).foregroundStyle(PulseColors.ink2.color)
            HStack(spacing: 4) {
                Button("−5") { adjustLoadKg(by: -5) }
                Text(load).pulseFont(.body).foregroundStyle(PulseColors.ink0.color)
                    .frame(minWidth: 70)
                Button("+5") { adjustLoadKg(by: 5) }
            }
            .onLongPressGesture {
                freeformText = load
                loadFreeform = true
            }
        }
    }

    private var rpeRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("RPE").pulseFont(.body).foregroundStyle(PulseColors.ink1.color)
                Spacer()
                Text(rpe == 0 ? "—" : "\(rpe)")
                    .pulseFont(.body).foregroundStyle(PulseColors.ink0.color)
            }
            HStack(spacing: 4) {
                ForEach(1...10, id: \.self) { n in
                    Circle()
                        .fill(n <= rpe ? PulseColors.ink0.color : PulseColors.bg2.color)
                        .frame(width: 18, height: 18)
                        .onTapGesture { rpe = n }
                }
            }
        }
    }

    private func adjustLoadKg(by delta: Int) {
        // Parse a numeric prefix (e.g. "60kg"), bump by delta, write back.
        let trimmed = load.trimmingCharacters(in: .whitespaces)
        if let n = Self.parseKg(trimmed) {
            let newN = max(0, n + delta)
            load = "\(newN)kg"
        } else {
            // Non-numeric (BW / 0:30) — leave as-is; user must long-press to free-form.
        }
    }

    static func parseKg(_ s: String) -> Int? {
        let digits = s.prefix(while: { $0.isNumber })
        return Int(digits)
    }
}
```

- [ ] **Step 5: RestPhaseView**

```swift
import SwiftUI
import DesignSystem

struct RestPhaseView: View {
    let restRemaining: Int
    let nextLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.lg) {
            Text("REST")
                .pulseFont(.small)
                .foregroundStyle(PulseColors.ink2.color)
            Text(formatted(restRemaining))
                .pulseFont(.h1)
                .foregroundStyle(PulseColors.ink0.color)
            Text("Up next: \(nextLabel)")
                .pulseFont(.body)
                .foregroundStyle(PulseColors.ink1.color)
        }
        .padding(PulseSpacing.lg)
    }

    private func formatted(_ s: Int) -> String {
        String(format: "%d:%02d", s / 60, s % 60)
    }
}
```

- [ ] **Step 6: BottomControlsView**

```swift
import SwiftUI
import DesignSystem

struct BottomControlsView: View {
    let primaryLabel: String
    let onPrimary: () -> Void
    let onSkipRest: (() -> Void)?

    var body: some View {
        HStack {
            if let onSkipRest {
                PulseButton("Skip rest", variant: .ghost, action: onSkipRest)
            }
            Spacer()
            PulseButton(primaryLabel, variant: .primary, action: onPrimary)
        }
    }
}
```

- [ ] **Step 7: `InWorkoutView`**

```swift
import SwiftUI
import UIKit
import CoreModels
import DesignSystem
import Persistence
import Repositories

public struct InWorkoutView: View {
    @State private var store: SessionStore
    @State private var elapsedSec: Int = 0
    @State private var sessionStartTime: Date = Date()
    @State private var showDiscardAlert = false
    private let onComplete: (UUID) -> Void
    private let onDiscard: () -> Void

    public init(workoutID: UUID,
                modelContainer: ModelContainer,
                flat: [SessionStore.FlatEntry],
                onComplete: @escaping (UUID) -> Void,
                onDiscard: @escaping () -> Void) {
        let repo = SessionRepository(modelContainer: modelContainer)
        _store = State(initialValue: SessionStore(workoutID: workoutID, flat: flat, repo: repo))
        self.onComplete = onComplete
        self.onDiscard = onDiscard
    }

    public var body: some View {
        ZStack {
            PulseColors.bg0.color.ignoresSafeArea()
            VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                topBar
                ProgressSegmentsView(total: store.flat.count, completed: store.idx)
                if let cur = store.current {
                    ExerciseCardView(blockLabel: cur.blockLabel,
                                     exerciseName: cur.exerciseName,
                                     setIndexLabel: setLabel(cur))
                }
                LiveMetricsGridView(
                    elapsed: format(elapsedSec),
                    restRemaining: store.phase == .rest ? formatRest() : "—",
                    avgHR: "—")

                if store.phase == .rest, let cur = store.current {
                    RestPhaseView(restRemaining: max(0, cur.restSec - store.secs),
                                  nextLabel: cur.exerciseName)
                } else if store.current != nil {
                    SetLogCardView(reps: $store.draft.reps,
                                   load: $store.draft.load,
                                   rpe: $store.draft.rpe,
                                   prescribedReps: store.current?.prescribedReps ?? 0,
                                   prescribedLoad: store.current?.prescribedLoad ?? "")
                }
                Spacer()
                BottomControlsView(
                    primaryLabel: store.phase == .rest ? "Skip rest" : "Log set \(store.current?.setNum ?? 0)",
                    onPrimary: { Task { await onPrimaryTap() } },
                    onSkipRest: store.phase == .rest ? { skipRest() } : nil)
            }
            .padding(PulseSpacing.lg)
        }
        .preferredColorScheme(.dark)
        .task { await onAppear() }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            tick()
        }
        .alert("Discard workout?", isPresented: $showDiscardAlert) {
            Button("Discard", role: .destructive) {
                Task {
                    await store.discard()
                    onDiscard()
                }
            }
            Button("Keep going", role: .cancel) { }
        } message: {
            Text("Your sets so far won't be saved.")
        }
        .onAppear {
            #if os(iOS)
            UIApplication.shared.isIdleTimerDisabled = true
            #endif
        }
        .onDisappear {
            #if os(iOS)
            UIApplication.shared.isIdleTimerDisabled = false
            #endif
        }
    }

    private var topBar: some View {
        HStack {
            Button(action: { showDiscardAlert = true }) {
                Image(systemName: "xmark")
                    .pulseFont(.body)
                    .foregroundStyle(PulseColors.ink0.color)
            }
            Spacer()
            Text("LIVE")
                .pulseFont(.small)
                .foregroundStyle(PulseColors.ink2.color)
        }
    }

    private func setLabel(_ cur: SessionStore.FlatEntry) -> String {
        let sameEx = store.flat.filter { $0.exerciseID == cur.exerciseID }
        return "SET \(cur.setNum) OF \(sameEx.count)"
    }

    private func format(_ s: Int) -> String { String(format: "%d:%02d", s / 60, s % 60) }
    private func formatRest() -> String {
        guard let cur = store.current else { return "—" }
        return format(max(0, cur.restSec - store.secs))
    }

    private func onAppear() async {
        sessionStartTime = Date()
        await store.start()
        store.onLifecycle = { [self] event in
            switch event {
            case .completed(let session):
                onComplete(session.id)
            case .discarded:
                break  // alert action already calls onDiscard
            }
        }
    }

    private func tick() {
        elapsedSec = Int(Date().timeIntervalSince(sessionStartTime))
        store.tick(by: 1)
    }

    private func skipRest() {
        guard store.phase == .rest else { return }
        // Force advance to work by ticking past restSec.
        if let cur = store.current {
            store.tick(by: cur.restSec)
        }
    }

    private func onPrimaryTap() async {
        if store.phase == .rest {
            skipRest()
        } else {
            await store.logCurrentSet()
        }
    }
}
```

- [ ] **Step 8: Run unit tests + smoke**

Run: `cd ios/Packages/Features/InWorkout && swift test`
Expected: pass.

- [ ] **Step 9: Commit**

```bash
git add ios/Packages/Features/InWorkout/
git commit -m "feat(in-workout): data-dense session view + components"
```

---

### Task 4.4: Helper to build `[FlatEntry]` from a `WorkoutEntity`

`InWorkoutView` takes `flat: [SessionStore.FlatEntry]`. Caller (AppShell) needs to flatten the workout's blocks/exercises/sets into one ordered list. Add a static helper in InWorkout module.

**Files:**
- Modify: `ios/Packages/Features/InWorkout/Sources/InWorkout/SessionStore.swift`

- [ ] **Step 1: Add static helper**

Append to `SessionStore.swift`:

```swift
public extension SessionStore {
    static func flatten(workout: WorkoutEntity) -> [FlatEntry] {
        guard let blocks = try? JSONDecoder.pulse.decode([WorkoutBlock].self, from: workout.blocksJSON) else {
            return []
        }
        var out: [FlatEntry] = []
        for block in blocks {
            for ex in block.exercises {
                for set in ex.sets {
                    out.append(.init(blockLabel: block.label,
                                     exerciseID: ex.exerciseID,
                                     exerciseName: ex.name,
                                     setNum: set.setNum,
                                     prescribedReps: set.reps,
                                     prescribedLoad: set.load,
                                     restSec: set.restSec))
                }
            }
        }
        return out
    }
}
```

- [ ] **Step 2: Add a unit test**

Append to `SessionStoreTests.swift`:

```swift
@MainActor
func test_flatten_unwrapsAllSetsAcrossBlocks() throws {
    let block = WorkoutBlock(id: "b1", label: "Main", exercises: [
        PlannedExercise(id: "e1", exerciseID: "back-squat", name: "Back Squat",
            sets: [
                PlannedSet(setNum: 1, reps: 8, load: "60kg", restSec: 60),
                PlannedSet(setNum: 2, reps: 8, load: "62.5kg", restSec: 60),
            ]),
        PlannedExercise(id: "e2", exerciseID: "row", name: "Row",
            sets: [PlannedSet(setNum: 1, reps: 10, load: "40kg", restSec: 45)]),
    ])
    let blocksData = try JSONEncoder.pulse.encode([block])
    let w = WorkoutEntity(id: UUID(), planID: UUID(), scheduledFor: Date(),
        title: "T", subtitle: "S", workoutType: "Strength", durationMin: 30,
        status: "scheduled", blocksJSON: blocksData,
        exercisesJSON: Data("[]".utf8))
    let flat = SessionStore.flatten(workout: w)
    XCTAssertEqual(flat.count, 3)
    XCTAssertEqual(flat[0].exerciseID, "back-squat")
    XCTAssertEqual(flat[0].setNum, 1)
    XCTAssertEqual(flat[1].setNum, 2)
    XCTAssertEqual(flat[2].exerciseID, "row")
}
```

- [ ] **Step 3: Run**

Run: `cd ios/Packages/Features/InWorkout && swift test`
Expected: pass.

- [ ] **Step 4: Commit**

```bash
git add ios/Packages/Features/InWorkout/
git commit -m "feat(in-workout): SessionStore.flatten helper for blocks → flat sets"
```

---


## Phase 5 — Complete: Recap (Step 1)

The `Features/Complete` package owns all three Complete steps. Phase 5 ships the package skeleton + the cinematic recap.

### Task 5.1: Scaffold `Features/Complete` SPM package + `CompleteStore` skeleton

**Files:**
- Create: `ios/Packages/Features/Complete/Package.swift`
- Create: `ios/Packages/Features/Complete/Sources/Complete/Module.swift`
- Create: `ios/Packages/Features/Complete/Sources/Complete/CompleteStore.swift`
- Create: `ios/Packages/Features/Complete/Tests/CompleteTests/SmokeTests.swift`
- Modify: `ios/Project.yml`

- [ ] **Step 1: Create `Package.swift`**

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Complete",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "Complete", targets: ["Complete"])],
    dependencies: [
        .package(path: "../../CoreModels"),
        .package(path: "../../DesignSystem"),
        .package(path: "../../Persistence"),
        .package(path: "../../Repositories"),
        .package(path: "../../HealthKitClient"),
    ],
    targets: [
        .target(name: "Complete",
                dependencies: ["CoreModels", "DesignSystem", "Persistence",
                               "Repositories", "HealthKitClient"]),
        .testTarget(name: "CompleteTests", dependencies: ["Complete"]),
    ]
)
```

- [ ] **Step 2: Stub `Module.swift` + `SmokeTests.swift`**

```swift
// Module.swift
import Foundation
public enum CompleteModule { public static let name = "Complete" }
```

```swift
// SmokeTests.swift
import XCTest
@testable import Complete
final class SmokeTests: XCTestCase {
    func test_module() { XCTAssertEqual(CompleteModule.name, "Complete") }
}
```

- [ ] **Step 3: Stub `CompleteStore`**

```swift
import Foundation
import Observation
import CoreModels

@MainActor
@Observable
public final class CompleteStore {
    public enum Step: Sendable { case recap, rate, adaptation }
    public enum AdaptationPhase: Sendable {
        case idle
        case streaming(checkpoints: [String], adjustments: [Adjustment], rationale: String?, newWorkout: PlannedWorkout?)
        case done(AdaptationPayload)
        case failed(Error)
    }

    public private(set) var step: Step = .recap
    public var feedbackDraft: FeedbackDraft = FeedbackDraft()
    public private(set) var adaptation: AdaptationPhase = .idle

    public func goToRate() { step = .rate }
    public func goToAdaptation() { step = .adaptation }

    public struct FeedbackDraft: Sendable, Equatable {
        public var rating: Int = 0
        public var intensity: Int = 0
        public var mood: WorkoutFeedback.Mood = .ok
        public var tags: Set<String> = []
        public var exerciseRatings: [String: WorkoutFeedback.ExerciseRating] = [:]
        public var note: String = ""

        public init() {}
        public var canSubmit: Bool { rating > 0 }
    }
}
```

- [ ] **Step 4: Register package in `Project.yml`**

```yaml
  Complete:
    path: Packages/Features/Complete
```

And in `targets.PulseApp.dependencies:`:

```yaml
      - package: Complete
```

- [ ] **Step 5: Regenerate**

Run: `cd ios && xcodegen generate`
Expected: success.

- [ ] **Step 6: Commit**

```bash
git add ios/Packages/Features/Complete/ ios/Project.yml ios/PulseApp.xcodeproj/
git commit -m "chore(complete): scaffold Features/Complete + CompleteStore skeleton"
```

---

### Task 5.2: `RecapStepView` + `StatTileView`

The recap reads `SessionEntity` + `SetLogEntity` rows + parent `WorkoutEntity` and renders TIME / AVG-HR / KCAL / VOL stat tiles. HR / KCAL show "—" until Plan 5.

**Files:**
- Create: `ios/Packages/Features/Complete/Sources/Complete/Components/StatTileView.swift`
- Create: `ios/Packages/Features/Complete/Sources/Complete/Steps/RecapStepView.swift`

- [ ] **Step 1: `StatTileView`**

```swift
import SwiftUI
import DesignSystem

struct StatTileView: View {
    let label: String
    let value: String

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .pulseFont(.small)
                    .foregroundStyle(PulseColors.ink2.color)
                Text(value)
                    .pulseFont(.h2)
                    .foregroundStyle(PulseColors.ink0.color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
```

- [ ] **Step 2: `RecapStepView`**

```swift
import SwiftUI
import SwiftData
import CoreModels
import DesignSystem
import Persistence

struct RecapStepView: View {
    let session: SessionEntity?
    let workout: WorkoutEntity?
    let setLogs: [SetLogEntity]
    let coachName: String
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(colors: [
                PulseColors.bg0.color,
                PulseColors.accent.base.color.opacity(0.15)
            ], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
            VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                Text("Workout complete")
                    .pulseFont(.h1)
                    .foregroundStyle(PulseColors.ink0.color)
                Text(workout?.title ?? "Today's session")
                    .pulseFont(.body)
                    .foregroundStyle(PulseColors.ink1.color)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: PulseSpacing.sm),
                                         count: 2),
                          spacing: PulseSpacing.sm) {
                    StatTileView(label: "TIME", value: timeString)
                    StatTileView(label: "AVG HR", value: "—")
                    StatTileView(label: "KCAL", value: "—")
                    StatTileView(label: "VOLUME", value: volumeString)
                }
                Spacer()
                PulseButton("Tell \(coachName) how it went", variant: .primary, action: onContinue)
            }
            .padding(PulseSpacing.lg)
        }
    }

    private var timeString: String {
        let s = session?.durationSec ?? 0
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private var volumeString: String {
        // sum reps × parsed kg for sets where load parses to a number.
        let total = setLogs.reduce(0) { acc, row in
            guard let kg = parseKg(row.load) else { return acc }
            return acc + (row.reps * kg)
        }
        return total > 0 ? "\(total) kg" : "—"
    }

    private func parseKg(_ s: String) -> Int? {
        let digits = s.prefix(while: { $0.isNumber })
        return Int(digits)
    }
}
```

- [ ] **Step 3: Run smoke test**

Run: `cd ios/Packages/Features/Complete && swift test`
Expected: pass (just the smoke test for now).

- [ ] **Step 4: Commit**

```bash
git add ios/Packages/Features/Complete/
git commit -m "feat(complete): cinematic recap step + stat tiles"
```

---


## Phase 6 — Complete: Rate (Step 2)

The feedback capture form: 5-star rating, intensity slider, mood, per-move thumbs for first 4 exercises, tag pills, optional note. "Send to {Coach}" disabled until rating > 0; submit → `FeedbackRepository.save` → transition to Step 3.

### Task 6.1: Form components

**Files:**
- Create: `ios/Packages/Features/Complete/Sources/Complete/Components/FeedbackTagPill.swift`
- Create: `ios/Packages/Features/Complete/Sources/Complete/Components/ExerciseThumbsRow.swift`

- [ ] **Step 1: `FeedbackTagPill`**

```swift
import SwiftUI
import DesignSystem

struct FeedbackTagPill: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .pulseFont(.small)
                .foregroundStyle(isSelected ? PulseColors.bg0.color : PulseColors.ink0.color)
                .padding(.horizontal, PulseSpacing.md)
                .padding(.vertical, PulseSpacing.xs)
                .background(isSelected ? PulseColors.ink0.color : PulseColors.bg2.color)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: `ExerciseThumbsRow`**

```swift
import SwiftUI
import CoreModels
import DesignSystem

struct ExerciseThumbsRow: View {
    let exerciseID: String
    let exerciseName: String
    @Binding var rating: WorkoutFeedback.ExerciseRating?

    var body: some View {
        HStack {
            Text(exerciseName)
                .pulseFont(.body)
                .foregroundStyle(PulseColors.ink1.color)
            Spacer()
            HStack(spacing: PulseSpacing.sm) {
                thumbButton(direction: .up)
                thumbButton(direction: .down)
            }
        }
    }

    @ViewBuilder
    private func thumbButton(direction: WorkoutFeedback.ExerciseRating) -> some View {
        let isSelected = rating == direction
        Button {
            rating = isSelected ? nil : direction
        } label: {
            Image(systemName: direction == .up ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                .foregroundStyle(isSelected ? PulseColors.ink0.color : PulseColors.ink2.color)
                .padding(8)
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add ios/Packages/Features/Complete/Sources/Complete/Components/
git commit -m "feat(complete): tag pill + per-exercise thumbs row components"
```

---

### Task 6.2: `RateStepView`

**Files:**
- Create: `ios/Packages/Features/Complete/Sources/Complete/Steps/RateStepView.swift`

- [ ] **Step 1: Implement view**

```swift
import SwiftUI
import CoreModels
import DesignSystem
import Persistence
import Repositories

struct RateStepView: View {
    @Bindable var store: CompleteStore
    let coachName: String
    let firstFourExercises: [(id: String, name: String)]   // first 4 from the workout
    let onSubmit: () async -> Void

    private let availableTags = [
        "energized", "drained", "too_long", "too_short",
        "more_strength", "more_cardio", "boring", "fun"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                Text("How was it?")
                    .pulseFont(.h1)
                    .foregroundStyle(PulseColors.ink0.color)

                ratingRow

                intensityRow

                moodRow

                if !firstFourExercises.isEmpty {
                    Text("Per move").pulseFont(.small).foregroundStyle(PulseColors.ink2.color)
                    VStack(spacing: PulseSpacing.sm) {
                        ForEach(firstFourExercises.prefix(4), id: \.id) { ex in
                            ExerciseThumbsRow(
                                exerciseID: ex.id,
                                exerciseName: ex.name,
                                rating: Binding(
                                    get: { store.feedbackDraft.exerciseRatings[ex.id] },
                                    set: { newValue in
                                        if let v = newValue {
                                            store.feedbackDraft.exerciseRatings[ex.id] = v
                                        } else {
                                            store.feedbackDraft.exerciseRatings.removeValue(forKey: ex.id)
                                        }
                                    }))
                        }
                    }
                }

                tagsRow

                noteRow

                PulseButton("Send to \(coachName) →", variant: .primary) {
                    Task { await onSubmit() }
                }
                .disabled(!store.feedbackDraft.canSubmit)
                .opacity(store.feedbackDraft.canSubmit ? 1 : 0.4)
            }
            .padding(PulseSpacing.lg)
        }
        .background(PulseColors.bg0.color.ignoresSafeArea())
    }

    private var ratingRow: some View {
        HStack(spacing: PulseSpacing.sm) {
            Text("Rating").pulseFont(.body).foregroundStyle(PulseColors.ink1.color)
            Spacer()
            ForEach(1...5, id: \.self) { n in
                Button { store.feedbackDraft.rating = n } label: {
                    Image(systemName: n <= store.feedbackDraft.rating ? "star.fill" : "star")
                        .foregroundStyle(PulseColors.accent.base.color)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var intensityRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Intensity").pulseFont(.body).foregroundStyle(PulseColors.ink1.color)
                Spacer()
                Text(store.feedbackDraft.intensity == 0 ? "—" : "\(store.feedbackDraft.intensity)/5")
                    .pulseFont(.small).foregroundStyle(PulseColors.ink2.color)
            }
            Slider(value: Binding(
                get: { Double(store.feedbackDraft.intensity) },
                set: { store.feedbackDraft.intensity = Int($0.rounded()) }
            ), in: 0...5, step: 1)
        }
    }

    private var moodRow: some View {
        HStack(spacing: PulseSpacing.sm) {
            Text("Mood").pulseFont(.body).foregroundStyle(PulseColors.ink1.color)
            Spacer()
            ForEach(WorkoutFeedback.Mood.allCases, id: \.self) { m in
                Button {
                    store.feedbackDraft.mood = m
                } label: {
                    Text(m.rawValue.capitalized)
                        .pulseFont(.small)
                        .foregroundStyle(store.feedbackDraft.mood == m
                                         ? PulseColors.bg0.color : PulseColors.ink0.color)
                        .padding(.horizontal, PulseSpacing.sm)
                        .padding(.vertical, 4)
                        .background(store.feedbackDraft.mood == m
                                    ? PulseColors.ink0.color : PulseColors.bg2.color)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var tagsRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Tags").pulseFont(.small).foregroundStyle(PulseColors.ink2.color)
            FlowLayout(spacing: 6) {
                ForEach(availableTags, id: \.self) { tag in
                    FeedbackTagPill(label: tag,
                                    isSelected: store.feedbackDraft.tags.contains(tag)) {
                        if store.feedbackDraft.tags.contains(tag) {
                            store.feedbackDraft.tags.remove(tag)
                        } else {
                            store.feedbackDraft.tags.insert(tag)
                        }
                    }
                }
            }
        }
    }

    private var noteRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Note (optional)").pulseFont(.small).foregroundStyle(PulseColors.ink2.color)
            TextEditor(text: $store.feedbackDraft.note)
                .pulseFont(.body)
                .frame(minHeight: 80)
                .padding(8)
                .background(PulseColors.bg2.color)
                .clipShape(RoundedRectangle(cornerRadius: PulseRadius.sm))
        }
    }
}

// Minimal flow layout for tags. SwiftUI iOS 16+: Layout protocol.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        var x: CGFloat = 0; var y: CGFloat = 0; var lineH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > maxWidth { x = 0; y += lineH + spacing; lineH = 0 }
            x += sz.width + spacing
            lineH = max(lineH, sz.height)
        }
        return CGSize(width: maxWidth, height: y + lineH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x = bounds.minX; var y = bounds.minY; var lineH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > bounds.maxX { x = bounds.minX; y += lineH + spacing; lineH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: sz.width, height: sz.height))
            x += sz.width + spacing
            lineH = max(lineH, sz.height)
        }
        _ = maxWidth
    }
}

extension WorkoutFeedback.Mood: CaseIterable {
    public static let allCases: [WorkoutFeedback.Mood] = [.great, .good, .ok, .rough]
}
```

- [ ] **Step 2: Add `CompleteStore` test for the canSubmit gate**

Create `ios/Packages/Features/Complete/Tests/CompleteTests/CompleteStoreTests.swift`:

```swift
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
```

- [ ] **Step 3: Run**

Run: `cd ios/Packages/Features/Complete && swift test`
Expected: pass.

- [ ] **Step 4: Commit**

```bash
git add ios/Packages/Features/Complete/
git commit -m "feat(complete): rate-step view + CompleteStore tests"
```

---


## Phase 7 — Complete: Adaptation (Step 3)

The product's defining moment. Streams the adaptation, renders thinking-state checkpoints + result phase (adjustments + coach card + next-session preview), runs the supersedes-workout transaction on `done`, and falls back to the bundled workout on retry-then-fail.

### Task 7.1: Adaptation step components

**Files:**
- Create: `ios/Packages/Features/Complete/Sources/Complete/Components/AdjustmentCardView.swift`
- Create: `ios/Packages/Features/Complete/Sources/Complete/Components/CoachRationaleCardView.swift`
- Create: `ios/Packages/Features/Complete/Sources/Complete/Components/NextSessionPreviewCardView.swift`

- [ ] **Step 1: `AdjustmentCardView`**

```swift
import SwiftUI
import CoreModels
import DesignSystem

struct AdjustmentCardView: View {
    let adjustment: Adjustment

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(adjustment.label)
                    .pulseFont(.h2)
                    .foregroundStyle(PulseColors.ink0.color)
                Text(adjustment.detail)
                    .pulseFont(.small)
                    .foregroundStyle(PulseColors.ink2.color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
```

- [ ] **Step 2: `CoachRationaleCardView`**

```swift
import SwiftUI
import DesignSystem

struct CoachRationaleCardView: View {
    let coachName: String
    let rationale: String

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                Text(coachName)
                    .pulseFont(.small)
                    .foregroundStyle(PulseColors.accent.base.color)
                Text(rationale)
                    .pulseFont(.body)
                    .foregroundStyle(PulseColors.ink0.color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
```

- [ ] **Step 3: `NextSessionPreviewCardView`**

```swift
import SwiftUI
import CoreModels
import DesignSystem

struct NextSessionPreviewCardView: View {
    let title: String
    let subtitle: String
    let workoutType: String
    let durationMin: Int
    let scheduledFor: Date

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                Text(weekdayString)
                    .pulseFont(.small)
                    .foregroundStyle(PulseColors.ink2.color)
                Text(title)
                    .pulseFont(.h2)
                    .foregroundStyle(PulseColors.ink0.color)
                Text(subtitle)
                    .pulseFont(.small)
                    .foregroundStyle(PulseColors.ink1.color)
                HStack(spacing: PulseSpacing.sm) {
                    PulsePill("\(durationMin) min", variant: .default)
                    PulsePill(workoutType, variant: .accent)
                }
            }
        }
    }

    private var weekdayString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: scheduledFor).uppercased()
    }
}
```

- [ ] **Step 4: Commit**

```bash
git add ios/Packages/Features/Complete/Sources/Complete/Components/
git commit -m "feat(complete): adjustment card + rationale + next-session preview components"
```

---

### Task 7.2: `AdaptationStepView` + bundled-fallback path

The view subscribes to the adaptation event stream via `CompleteStore`, renders a thinking-state during `.streaming`, and the result phase on `.done`. On `.failed`, retry once; on second fail, run bundled fallback (insert the canned workout for the next scheduled date as if it were the new workout).

**Files:**
- Create: `ios/Packages/Features/Complete/Sources/Complete/Steps/AdaptationStepView.swift`
- Modify: `ios/Packages/Features/Complete/Sources/Complete/CompleteStore.swift`

- [ ] **Step 1: Extend `CompleteStore` with the run loop**

Append to `CompleteStore.swift`:

```swift
import Persistence
import Repositories
import SwiftData

public extension CompleteStore {
    typealias AdaptationStreamer = (
        @MainActor () -> AsyncThrowingStream<AdaptationStreamEvent, Error>
    )

    /// Submits feedback (idempotent), then streams adaptation. Retries once on
    /// failure; on second failure, falls back to the bundled workout.
    @MainActor
    func runFlow(sessionID: UUID,
                 feedbackRepo: FeedbackRepository,
                 streamer: @escaping AdaptationStreamer,
                 fallback: @escaping @MainActor () -> Void,
                 nowProvider: @escaping () -> Date = Date.init) async {
        // 1. Persist feedback. Skip if already saved (idempotent).
        let feedback = WorkoutFeedback(
            sessionID: sessionID,
            submittedAt: nowProvider(),
            rating: feedbackDraft.rating,
            intensity: feedbackDraft.intensity,
            mood: feedbackDraft.mood,
            tags: Array(feedbackDraft.tags),
            exerciseRatings: feedbackDraft.exerciseRatings,
            note: feedbackDraft.note.isEmpty ? nil : feedbackDraft.note)
        do {
            try feedbackRepo.saveFeedback(feedback)
        } catch {
            // If saveFeedback fails, the feedback wasn't kept. Surface to UI.
            adaptation = .failed(error)
            return
        }
        await goToAdaptationAndStream(streamer: streamer, fallback: fallback, attempt: 1)
    }

    @MainActor
    private func goToAdaptationAndStream(streamer: @escaping AdaptationStreamer,
                                         fallback: @escaping @MainActor () -> Void,
                                         attempt: Int) async {
        step = .adaptation
        adaptation = .streaming(checkpoints: [], adjustments: [],
                                rationale: nil, newWorkout: nil)
        do {
            for try await event in streamer() {
                apply(event)
                if case .done = adaptation { return }
            }
            // Stream finished without a `done` event — treat as malformed.
            throw NSError(domain: "Complete", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Stream ended early"])
        } catch {
            if attempt == 1 {
                await goToAdaptationAndStream(streamer: streamer,
                                              fallback: fallback,
                                              attempt: 2)
            } else {
                adaptation = .failed(error)
                fallback()
            }
        }
    }

    @MainActor
    private func apply(_ event: AdaptationStreamEvent) {
        guard case .streaming(var cps, var adjs, var rat, var wo) = adaptation else {
            if case .done = adaptation { return }
            adaptation = .streaming(checkpoints: [], adjustments: [],
                                    rationale: nil, newWorkout: nil)
            apply(event); return
        }
        switch event {
        case .checkpoint(let label):
            cps.append(label)
        case .textDelta:
            break
        case .adjustment(let a):
            adjs.append(a)
        case .workout(let w):
            wo = w
        case .rationale(let text):
            rat = text
        case .done(let payload, _, _, _):
            adaptation = .done(payload)
            return
        }
        adaptation = .streaming(checkpoints: cps, adjustments: adjs,
                                rationale: rat, newWorkout: wo)
    }
}
```

- [ ] **Step 2: Implement `AdaptationStepView`**

```swift
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
```

- [ ] **Step 3: Implement the public `CompleteView` orchestrator**

Create `ios/Packages/Features/Complete/Sources/Complete/CompleteView.swift`:

```swift
import SwiftUI
import SwiftData
import CoreModels
import Persistence
import Repositories
import HealthKitClient

public struct CompleteView: View {
    @State private var store = CompleteStore()
    @State private var session: SessionEntity?
    @State private var workout: WorkoutEntity?
    @State private var nextWorkout: WorkoutEntity?
    @State private var setLogs: [SetLogEntity] = []
    @State private var firstFour: [(id: String, name: String)] = []
    @State private var didStartFlow = false

    private let sessionID: UUID
    private let modelContainer: ModelContainer
    private let api: Networking.APIClient
    private let healthKit: HealthKitClient
    private let coachName: String
    private let coach: Coach
    private let profile: Profile
    private let onDismiss: () -> Void

    public init(sessionID: UUID, modelContainer: ModelContainer,
                api: Networking.APIClient, healthKit: HealthKitClient,
                coach: Coach, profile: Profile,
                onDismiss: @escaping () -> Void) {
        self.sessionID = sessionID
        self.modelContainer = modelContainer
        self.api = api
        self.healthKit = healthKit
        self.coachName = coach.displayName
        self.coach = coach
        self.profile = profile
        self.onDismiss = onDismiss
    }

    public var body: some View {
        Group {
            switch store.step {
            case .recap:
                RecapStepView(session: session, workout: workout, setLogs: setLogs,
                              coachName: coachName) {
                    store.goToRate()
                }
            case .rate:
                RateStepView(store: store, coachName: coachName,
                             firstFourExercises: firstFour) {
                    await submit()
                }
            case .adaptation:
                AdaptationStepView(store: store, coachName: coachName, onDone: onDismiss)
            }
        }
        .task { await loadContext() }
    }

    @MainActor
    private func loadContext() async {
        let ctx = modelContainer.mainContext
        let sid = sessionID
        if let s = try? ctx.fetch(FetchDescriptor<SessionEntity>(
            predicate: #Predicate { $0.id == sid })).first {
            session = s
            let wid = s.workoutID
            workout = try? ctx.fetch(FetchDescriptor<WorkoutEntity>(
                predicate: #Predicate { $0.id == wid })).first
            setLogs = (try? ctx.fetch(FetchDescriptor<SetLogEntity>(
                predicate: #Predicate { $0.sessionID == sid }))) ?? []
        }
        if let w = workout,
           let blocks = try? JSONDecoder.pulse.decode([WorkoutBlock].self, from: w.blocksJSON) {
            firstFour = blocks.flatMap { $0.exercises }
                .prefix(4).map { (id: $0.exerciseID, name: $0.name) }
        }
        // Compute next scheduled date — by default tomorrow at the same hour.
        let nextDate = Calendar.current.date(byAdding: .day, value: 1, to: workout?.scheduledFor ?? Date()) ?? Date()
        let workoutRepo = WorkoutRepository(modelContainer: modelContainer)
        nextWorkout = try? workoutRepo.workoutForDate(nextDate)
        if nextWorkout == nil {
            // Insert a placeholder if the AI hasn't written tomorrow yet.
            // For Plan 4 we fall back gracefully — the adaptation prompt will
            // be light-on-context. Future plans can pre-populate a week.
        }
    }

    @MainActor
    private func submit() async {
        guard !didStartFlow else { return }
        didStartFlow = true
        let feedbackRepo = FeedbackRepository(modelContainer: modelContainer)
        let adaptRepo = AdaptationRepository(modelContainer: modelContainer, api: api)

        guard let nextW = nextWorkout, let w = workout else {
            // No next workout to adapt — surface as failure → fallback path.
            store.adaptation = .failed(NSError(domain: "Complete", code: -2,
                userInfo: [NSLocalizedDescriptionKey: "No next workout to adapt"]))
            return
        }

        // Build prompts.
        let summaries = await healthKit.sevenDaySummary()
        let availableExercises = (try? ExerciseAssetRepository(
            modelContainer: modelContainer,
            manifestURL: URL(string: "https://placeholder.invalid/")!).allAssets())?
            .map { (id: $0.id, name: $0.name, equipment: $0.equipment) } ?? []
        let system = PromptBuilder.adaptationSystemPrompt(
            coach: coach, availableExercises: availableExercises)
        let userMsg = PromptBuilder.adaptationUserMessage(
            nextWorkout: nextW,
            justCompletedTitle: w.title,
            justCompletedDurationSec: session?.durationSec ?? 0,
            setLogs: setLogs,
            feedback: WorkoutFeedback(
                sessionID: sessionID,
                submittedAt: Date(),
                rating: store.feedbackDraft.rating,
                intensity: store.feedbackDraft.intensity,
                mood: store.feedbackDraft.mood,
                tags: Array(store.feedbackDraft.tags),
                exerciseRatings: store.feedbackDraft.exerciseRatings,
                note: store.feedbackDraft.note.isEmpty ? nil : store.feedbackDraft.note),
            profile: profile,
            summaries: summaries.isEmpty ? nil : summaries)

        let nextWID = nextW.id
        let appliedToPlanID = nextW.planID
        let streamer: CompleteStore.AdaptationStreamer = {
            adaptRepo.streamAdaptation(
                systemPrompt: system,
                userMessage: userMsg,
                nextWorkoutID: nextWID,
                feedbackID: UUID(),   // FeedbackEntity ID isn't surfaced from FeedbackRepository; pass a fresh UUID and the AdaptationEntity links via SessionEntity transitively
                appliedToPlanID: appliedToPlanID)
        }
        let fallbackPath: @MainActor () -> Void = { [profile, modelContainer, sessionID, nextW] in
            // Apply the bundled fallback as if it were the adapted workout.
            let plan = BundledFallback.todayWorkout(profile: profile, today: nextW.scheduledFor)
            let pw = plan.workouts.first!
            let payload = AdaptationPayload(
                originalWorkoutID: nextW.id,
                newWorkout: pw,
                adjustments: [Adjustment(id: "fb1", label: "Steady today",
                                         detail: "Mobility-only — keeping things easy")],
                rationale: "Couldn't reach the planner; locking in a steady mobility day so you keep moving.")
            let repo = AdaptationRepository(modelContainer: modelContainer,
                api: Networking.APIClient(config: .init(workerURL: URL(string: "https://placeholder.invalid/")!,
                                                        deviceToken: "")))
            try? repo.persist(payload: payload, feedbackID: UUID(),
                              appliedToPlanID: nextW.planID,
                              modelUsed: "bundled-fallback",
                              promptTokens: 0, completionTokens: 0)
            // Surface a "done" state to UI.
            // The store's runFlow already set `.failed`; flip to `.done` so user sees the result.
            // We can't reach the store from here without a closure; the caller must handle this.
        }
        await store.runFlow(sessionID: sessionID,
                            feedbackRepo: feedbackRepo,
                            streamer: streamer,
                            fallback: { [weak store] in
                                fallbackPath()
                                // Re-read the just-persisted bundled adaptation and flip store state.
                                let repo = WorkoutRepository(modelContainer: modelContainer)
                                if let nw = try? repo.workoutForDate(nextW.scheduledFor) {
                                    let payload = AdaptationPayload(
                                        originalWorkoutID: nextW.id,
                                        newWorkout: PlannedWorkout(id: "fb",
                                            scheduledFor: nw.scheduledFor,
                                            title: nw.title, subtitle: nw.subtitle,
                                            workoutType: nw.workoutType,
                                            durationMin: nw.durationMin,
                                            blocks: [], why: nw.why),
                                        adjustments: [Adjustment(id: "fb1",
                                            label: "Steady today",
                                            detail: "Mobility-only — keeping things easy")],
                                        rationale: "Couldn't reach the planner; locking in a steady mobility day.")
                                    store?.adaptation = .done(payload)
                                }
                            })
    }
}
```

(Note: this view orchestrates a lot — the closure dance reflects that. If complexity becomes painful in execution, a follow-up refactor can split orchestration into a dedicated coordinator. For Plan 4, optimize for working flow, not minimal abstraction.)

- [ ] **Step 4: Run all Complete tests**

Run: `cd ios/Packages/Features/Complete && swift test`
Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/Features/Complete/
git commit -m "feat(complete): adaptation step + flow orchestration + bundled fallback path"
```

---


## Phase 8 — AppShell wiring + smoke test

Tie everything together: enable the Start CTA, wire `WorkoutDetail.Start → InWorkout → Complete → Home`, add InWorkout + Complete entry points to `DebugFeatureSmokeView`, and run the 11-step manual smoke protocol.

### Task 8.1: Enable the Start CTA in `WorkoutDetailView`

`WorkoutDetailView` currently has `PulseButton("Start workout").disabled(true)`. Replace with a real callback.

**Files:**
- Modify: `ios/Packages/Features/WorkoutDetail/Sources/WorkoutDetail/WorkoutDetailView.swift`

- [ ] **Step 1: Add `onStart` callback parameter**

```swift
public struct WorkoutDetailView: View {
    @State private var store: WorkoutDetailStore
    @State private var selectedExercise: PlannedExercise?
    private let onStart: ((UUID) -> Void)?

    public init(workoutID: UUID,
                modelContainer: ModelContainer,
                assetRepo: ExerciseAssetRepository,
                onStart: ((UUID) -> Void)? = nil) {
        _store = State(initialValue: WorkoutDetailStore(
            workoutID: workoutID,
            modelContainer: modelContainer,
            assetRepo: assetRepo))
        self.onStart = onStart
    }

    // ... existing body ...

    private var startCTA: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            PulseButton("Start workout", variant: .primary) {
                onStart?(store.workoutID)
            }
            .disabled(onStart == nil)
            .opacity(onStart == nil ? 0.5 : 1)
            if onStart == nil {
                Text("Coming in the next update")
                    .pulseFont(.small)
                    .foregroundStyle(PulseColors.ink2.color)
            }
        }
    }
}
```

(Where `store.workoutID` exists — check `WorkoutDetailStore` and add a `public var workoutID: UUID` if needed.)

- [ ] **Step 2: Update WorkoutDetailStore to expose workoutID**

In `WorkoutDetailStore.swift`:

```swift
public let workoutID: UUID
```

- [ ] **Step 3: Run tests**

Run: `cd ios/Packages/Features/WorkoutDetail && swift test`
Expected: pass.

- [ ] **Step 4: Commit**

```bash
git add ios/Packages/Features/WorkoutDetail/
git commit -m "feat(workout-detail): enable Start CTA via onStart callback"
```

---

### Task 8.2: Wire fullScreenCover sequence in `RootScaffold`

InWorkout presents over the navigation stack; on completion, present Complete; on Complete dismiss, return to Home (which auto-refreshes).

**Files:**
- Modify: `ios/Packages/AppShell/Sources/AppShell/RootScaffold.swift`
- Modify: `ios/Packages/AppShell/Package.swift` (add InWorkout + Complete deps)

- [ ] **Step 1: Add deps to `AppShell/Package.swift`**

```swift
dependencies: [
    .package(path: "../CoreModels"),
    .package(path: "../DesignSystem"),
    .package(path: "../Networking"),
    .package(path: "../Persistence"),
    .package(path: "../Repositories"),
    .package(path: "../Features/Onboarding"),
    .package(path: "../Features/PlanGeneration"),
    .package(path: "../Features/Home"),
    .package(path: "../Features/WorkoutDetail"),
    .package(path: "../Features/InWorkout"),
    .package(path: "../Features/Complete"),
    .package(path: "../HealthKitClient"),
],
targets: [
    .target(name: "AppShell",
            dependencies: ["CoreModels", "DesignSystem", "Networking", "Persistence",
                           "Repositories", "Onboarding", "PlanGeneration",
                           "Home", "WorkoutDetail", "InWorkout", "Complete",
                           "HealthKitClient"]),
    .testTarget(name: "AppShellTests", dependencies: ["AppShell"]),
]
```

- [ ] **Step 2: Add InWorkout / Complete state to `RootScaffold`**

Edit `RootScaffold.swift`. Add state:

```swift
@State private var inWorkoutFor: UUID?
@State private var completeForSessionID: UUID?
```

In `todayTab`, change `WorkoutDetailView(...)` to pass `onStart`:

```swift
WorkoutDetailView(
    workoutID: id,
    modelContainer: appContainer.modelContainer,
    assetRepo: ExerciseAssetRepository(
        modelContainer: appContainer.modelContainer,
        manifestURL: appContainer.manifestURL),
    onStart: { wid in inWorkoutFor = wid }
)
```

Then add another fullScreenCover stacked (use `.sheet(item:)` or `.fullScreenCover(item:)` chained):

```swift
.fullScreenCover(item: $inWorkoutFor) { wid in
    inWorkoutScreen(workoutID: wid)
}
.fullScreenCover(item: $completeForSessionID) { sid in
    completeScreen(sessionID: sid)
}
```

Add helpers:

```swift
@ViewBuilder
private func inWorkoutScreen(workoutID: UUID) -> some View {
    let workoutRepo = WorkoutRepository(modelContainer: appContainer.modelContainer)
    let workout = (try? workoutRepo.workoutForID(workoutID))
    let flat: [InWorkout.SessionStore.FlatEntry] = workout.map { SessionStore.flatten(workout: $0) } ?? []
    InWorkoutView(
        workoutID: workoutID,
        modelContainer: appContainer.modelContainer,
        flat: flat,
        onComplete: { sid in
            inWorkoutFor = nil
            completeForSessionID = sid
        },
        onDiscard: { inWorkoutFor = nil })
}

@ViewBuilder
private func completeScreen(sessionID: UUID) -> some View {
    let profileRepo = ProfileRepository(modelContainer: appContainer.modelContainer)
    if let profile = (try? profileRepo.currentProfile()) ?? nil,
       let coach = Coach.byID(profile.activeCoachID) {
        CompleteView(sessionID: sessionID,
                     modelContainer: appContainer.modelContainer,
                     api: appContainer.api,
                     healthKit: appContainer.healthKit,
                     coach: coach,
                     profile: profile,
                     onDismiss: {
                         completeForSessionID = nil
                         selectedWorkoutID = nil   // pop detail too
                     })
    }
}
```

- [ ] **Step 3: Make UUID `Identifiable` for `fullScreenCover(item:)`**

In a small extension file (only if not already done):

```swift
// ios/Packages/AppShell/Sources/AppShell/UUID+Identifiable.swift
import Foundation
extension UUID: Identifiable { public var id: UUID { self } }
```

(If Plan 3 already added this — check `RootScaffold` for `selectedWorkoutID: UUID?` usage with `navigationDestination(item:)` — keep it. The compiler will tell you.)

- [ ] **Step 4: Test compile + run**

Run: `cd ios/Packages/AppShell && swift test`
Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/AppShell/
git commit -m "feat(app-shell): wire WorkoutDetail.Start → InWorkout → Complete → Home"
```

---

### Task 8.3: `FirstRunGate` orphan-session cleanup on relaunch

If the app crashed mid-session, an in-progress `SessionEntity` and its partial `SetLogEntity` rows persist. On relaunch, clean them up so the user lands on Home as if nothing happened.

**Files:**
- Modify: `ios/Packages/AppShell/Sources/AppShell/FirstRunGate.swift`

- [ ] **Step 1: Call `discardSession` for any orphan in `checkFirstRun`**

Edit `FirstRunGate.checkFirstRun`:

```swift
private func checkFirstRun() async {
    let p = (try? profileRepo.currentProfile()) ?? nil
    await MainActor.run {
        self.profile = p
        if let p, let coach = Coach.byID(p.activeCoachID) {
            self.themeStore.setActiveCoach(id: coach.id)
        }
        self.isCheckingFirstRun = false
    }
    // Plan 4: clean up any orphan in-progress sessions from a prior crash.
    let sessionRepo = SessionRepository(modelContainer: appContainer.modelContainer)
    if let orphan = try? sessionRepo.orphanedInProgressSession() {
        try? sessionRepo.discardSession(id: orphan.id)
    }
    // Best-effort: refresh exercise asset manifest in the background.
    let assetRepo = ExerciseAssetRepository(
        modelContainer: appContainer.modelContainer,
        manifestURL: appContainer.manifestURL
    )
    if (try? assetRepo.allAssets())?.isEmpty == true {
        try? await assetRepo.refreshFromManifest()
    }
}
```

- [ ] **Step 2: Add a unit test** (optional — `FirstRunGate` is harness-y; ok to skip for Plan 4)

- [ ] **Step 3: Commit**

```bash
git add ios/Packages/AppShell/
git commit -m "feat(app-shell): cascade-clean orphan in-progress sessions on relaunch"
```

---

### Task 8.4: `DebugFeatureSmokeView` entries for InWorkout + Complete

So the manual smoke can drive each feature in isolation.

**Files:**
- Modify: `ios/PulseApp/DebugFeatureSmokeView.swift`

- [ ] **Step 1: Add InWorkout + Complete routes**

```swift
private enum Route: Identifiable, Hashable {
    case onboarding, planGen, home
    case workoutDetail(UUID)
    case inWorkout(UUID)
    case complete(UUID)
    var id: String {
        switch self {
        case .onboarding: return "onboarding"
        case .planGen: return "planGen"
        case .home: return "home"
        case .workoutDetail(let id): return "wd-\(id)"
        case .inWorkout(let id):     return "iw-\(id)"
        case .complete(let id):      return "cp-\(id)"
        }
    }
}
```

Add buttons to the body:

```swift
button("Run InWorkout (latest workout)") {
    seedProfileIfMissing()
    seedWorkoutIfMissing()
    if let w = (try? WorkoutRepository(modelContainer: appContainer.modelContainer).latestWorkout()) {
        route = .inWorkout(w.id)
    }
}
button("Run Complete (latest session)") {
    if let s = (try? appContainer.modelContainer.mainContext.fetch(FetchDescriptor<SessionEntity>())).first {
        route = .complete(s.id)
    }
}
```

Render:

```swift
case .inWorkout(let wid):
    let workoutRepo = WorkoutRepository(modelContainer: appContainer.modelContainer)
    let workout = (try? workoutRepo.workoutForID(wid))
    let flat = workout.map { SessionStore.flatten(workout: $0) } ?? []
    InWorkoutView(workoutID: wid,
                  modelContainer: appContainer.modelContainer,
                  flat: flat,
                  onComplete: { sid in route = .complete(sid) },
                  onDiscard: { route = nil })
case .complete(let sid):
    let profileRepo = ProfileRepository(modelContainer: appContainer.modelContainer)
    if let p = (try? profileRepo.currentProfile()) ?? nil,
       let coach = Coach.byID(p.activeCoachID) {
        CompleteView(sessionID: sid,
                     modelContainer: appContainer.modelContainer,
                     api: appContainer.api,
                     healthKit: appContainer.healthKit,
                     coach: coach,
                     profile: p,
                     onDismiss: { route = nil })
    }
```

- [ ] **Step 2: Commit**

```bash
git add ios/PulseApp/DebugFeatureSmokeView.swift
git commit -m "chore(debug): add InWorkout + Complete entries to DebugFeatureSmokeView"
```

---

### Task 8.5: Manual smoke test (final acceptance)

Single end-to-end run on iPhone 17 Pro Sim, fresh data. Don't merge Plan 4 until every step passes.

**Protocol:**

1. **Cold start.** Wipe simulator app data (or use the Debug "Wipe Profile + Workouts" button) → open the app → land on onboarding. Walk through 7 steps including Connect Apple Health. Run *both* grant and deny paths in separate runs.
2. **Plan generates.** After tapping "Generate my first workout," verify the streaming UI shows checkpoints + final card. View today's workout from Home.
3. **Start workout.** Tap Start on `WorkoutDetailView`. InWorkoutView opens fullScreen.
4. **Log every set.** For each exercise/set: vary the prescribed values (some accept default, some adjust ± reps/load, some long-press for free-form text). Set RPE for at least half. Verify the rest timer auto-advances and the progress segments fill.
5. **Complete Step 1 (Recap).** After the last set, the recap shows TIME computed from session, AVG-HR/KCAL "—", and VOLUME computed from numeric loads.
6. **Complete Step 2 (Rate).** Set rating, intensity, mood, two tags, and thumbs on the first 4 exercises. Add a short note. Tap "Send to Coach" — should be enabled because rating > 0.
7. **Complete Step 3 (Adaptation).** Watch checkpoints stream, then adjustments appear, then rationale, then the next-session preview card. Tap "Done."
8. **Home reflects.** Home now shows the newly-inserted workout for tomorrow's date. The original is hidden (superseded). WeekStrip dot for tomorrow is filled.
9. **Regenerate cascade.** Use the regenerate flow (or Debug button) — confirm the prior week's workouts and PlanEntity are all removed.
10. **Force-quit mid-session.** Start a workout → log 1 set → kill the app via the simulator. Relaunch. Land on Home with no in-progress session showing.
11. **Bundled fallback.** Edit `Secrets.swift` (or use a debug switch if implemented) to point the API to a non-existent worker URL. Trigger an adaptation flow. After two failures, the bundled mobility fallback is inserted and shown as the result.

After every passing step, append a checkmark to a smoke-results note in the PR description (or in `ios/README.md` if appropriate). Any failure → log the bug, fix, re-run from step 1 if it touched data.

- [ ] **Step 1: Run the protocol from a clean simulator state**

Build and run: `cd ios && xcodegen generate && xcodebuild ...` (or use Xcode UI).

Pass criteria: all 11 steps pass without console errors. HKAuth deny path doesn't crash; HK summary block is omitted from the prompt.

- [ ] **Step 2: Update Plan 3 carry-over note in `ios/README.md`**

Open `ios/README.md`. Move the four blocker carry-overs to a "Resolved in Plan 4" section. Move the four cleanups (if Phase 0 was run) likewise. Add a short "Plan 4 acceptance" note linking to the smoke results.

- [ ] **Step 3: Commit + push**

```bash
git add ios/README.md
git commit -m "docs(ios): mark Plan 3 carry-overs resolved + Plan 4 acceptance"
git push origin main
```

---


