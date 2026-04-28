# Pulse — Plan 3: Phone-only Feature Slice (Design)

**Status:** Draft, ready for implementation planning
**Date:** 2026-04-28
**Audience:** Solo developer; this spec scopes the four phone-only features that sit on top of the Plan 2 foundation
**Master spec:** [`2026-04-26-pulse-ai-trainer-app-design.md`](./2026-04-26-pulse-ai-trainer-app-design.md). This document does not duplicate it; it specifies the design choices for the Plan 3 slice that the master spec leaves open.

---

## 1. Slice Summary

Plan 3 ships the user-facing flow from "first launch with no data" through "view today's generated workout":

1. **Onboarding** — 5-step quiz + coach selection
2. **PlanGeneration** — streaming LLM call with live checkpoint + prose UI
3. **Home** — today's workout hero, week strip, regenerate CTA
4. **WorkoutDetail** — hero + blocks list + exercise demos + non-functional Start CTA

The slice ends with the user staring at WorkoutDetail. The Start CTA is intentionally disabled — the in-workout flow, HealthKit, and Watch app land in Plan 4. Plan 5 covers Complete + Sentry + TestFlight.

This is a **non-trainable slice**: the user can configure their profile, see a generated workout, and inspect exercises, but cannot yet execute a session. Design choices below reflect that — anything whose value depends on completed sessions (weekly ring, week-strip status indicators, bundled fallback workout) is deferred to Plan 4.

---

## 2. Locked Decisions

Answers chosen during brainstorming. Inputs to planning, not open questions.

| Area | Decision |
|---|---|
| Scope | All four phone-only features (Onboarding + Home + PlanGen + WorkoutDetail) |
| Onboarding handoff | Auto-kick `PlanGenerationView(mode: .firstPlan)` immediately on completion. No "Home empty state" first-run path |
| PlanGen streaming UI | Mono checkpoint stack + raw model prose passthrough (truncates after ~6 lines so it never overwhelms) |
| Coach voice depth | Hue + ~12 voiced surfaces (4 coaches × 3 surfaces). All other strings neutral |
| Testing | Plan 2 parity — per-feature unit tests on `@Observable` stores + pure logic only; one sim-smoke entry per feature. No XCUITest |
| Day-N Home behavior | Latest plan regardless of date. No staleness logic. Manual Regenerate CTA |
| Architecture | Per-feature SPM packages under `Packages/Features/`, exactly as the master spec section 4 lays out |

---

## 3. Module Layout

Plan 3 adds four feature packages. None depend on each other; all consume shared infrastructure built in Plan 2.

```
PulseApp (target)
└── AppShell                                    ← Plan 2
    ├── Features/Onboarding         ← NEW (Plan 3)
    ├── Features/Home               ← NEW
    ├── Features/PlanGeneration     ← NEW
    └── Features/WorkoutDetail      ← NEW
                                    │
                                    ├── Repositories         ← Plan 2 (extended)
                                    ├── Networking            ← Plan 2 (unchanged)
                                    ├── Persistence           ← Plan 2 (unchanged)
                                    ├── DesignSystem          ← Plan 2 (unchanged)
                                    └── CoreModels            ← Plan 2 (extended)
```

### Repository extensions (in existing `Repositories` package)

- **`ProfileRepository`** — new repository
  - `currentProfile() async -> Profile?`
  - `save(_ profile: Profile) async throws`
- **`PlanRepository`** — new methods
  - `streamFirstPlan(profile:coach:) -> AsyncThrowingStream<PlanGenEvent, Error>`
  - `regenerate(profile:coach:) -> AsyncThrowingStream<PlanGenEvent, Error>` (same impl, different intent label)
  - `latestWorkout() async -> Workout?` — convenience over the existing fetch primitives, used by Home

### CoreModels additions (in existing `CoreModels` package)

- **`OnboardingDraft`** — in-memory aggregator carried by `OnboardingStore`. Not a SwiftData entity.
- **`PlanGenEvent`** — `enum { case checkpoint(label: String); case text(chunk: String); case done(WorkoutPlan); case failed(Error) }`
- **`CoachStrings`** — small lookup table of voiced copy (~12 strings; see §8)

### AppShell hook (in existing `AppShell` package)

`RootScaffold` gains a first-run branch on launch:

```swift
if profileRepo.currentProfile() == nil {
    // present OnboardingFlowView as .fullScreenCover
} else {
    // existing tabbed UI (Home tab + Settings tab placeholder)
}
```

Plan 2 shipped three tabs (`.today`, `.progress`, `.debug`). Plan 3 wires `HomeView` into the `.today` tab; `.progress` stays a placeholder shell (fills in during Plan 5 with stats/history); `.debug` keeps `DebugStreamView` and gains the new `DebugFeatureSmokeView` entry points (see §9 testing).

**No changes to:** Networking, Persistence, DesignSystem. Plan 2 already shipped what we need.

---

## 4. Onboarding Feature

**Module:** `Packages/Features/Onboarding`
**Public surface:** `OnboardingFlowView(onComplete: (Profile) async -> Void)`
**State:** `@Observable OnboardingStore` holds an in-memory `OnboardingDraft`. Profile writes once at the end (atomic). If the user kills the app mid-flow, they restart from step 1 — acceptable for a personal app.

### Six-step flow

| # | Step | Collects | Profile field(s) |
|---|---|---|---|
| 1 | Welcome + name | `displayName: String` | `displayName` |
| 2 | Goals | multi-select: build muscle, lose fat, get stronger, conditioning, mobility | `goals: [String]` |
| 3 | Experience level | single-select: new / regular / experienced / athlete | `level` |
| 4 | Equipment | multi-select: none, dumbbells, barbell, kettlebell, bands, full gym | `equipment: [String]` |
| 5 | Frequency + commitment | sessions/week (3/4/5/6) + minutes/session (30/45/60/90) | `frequency`, `weeklyTargetMinutes` |
| 6 | Coach pick | four cards (Ace/Rex/Vera/Mira) — name, vibe blurb, accent hue swatch | `activeCoachID`, `accentHue` |

### Validation

`OnboardingStore.canAdvance(from: step) -> Bool` is computed per step. The Next button is disabled until satisfied. No skipping. Back works between any two steps.

| Step | `canAdvance` requires |
|---|---|
| 1 | `draft.displayName.trimmingCharacters(in: .whitespaces).count >= 1` |
| 2 | `draft.goals.count >= 1` |
| 3 | `draft.level != nil` |
| 4 | `draft.equipment.count >= 1` |
| 5 | `draft.frequency != nil && draft.weeklyTargetMinutes != nil` |
| 6 | `draft.activeCoachID != nil` |

### Completion

On step 6 → Next, the store:
1. Builds a `Profile` from the draft
2. Calls `ProfileRepository.save(profile)`
3. Writes `ThemeStore.accentHue = profile.accentHue` so the next screen uses the chosen coach's accent immediately
4. Invokes `onComplete(profile)`

`AppShell`'s `onComplete` handler dismisses Onboarding and presents `PlanGenerationView(mode: .firstPlan)` as `.fullScreenCover`. (See Q2 in §2.)

### Voiced surface

Step 6's confirmation copy is coach-keyed via `CoachStrings.onboardingWelcome[coachID]`. Example targets (final wording during implementation):

- Ace: "Hey, I'm Ace. Let's build something."
- Rex: "Welcome — Rex. We're going to take this seriously."
- Vera: "Vera here. Tell me where you want to be in 12 weeks."
- Mira: "I'm Mira. We'll start where you are."

---

## 5. PlanGeneration Feature

**Module:** `Packages/Features/PlanGeneration`
**Public surface:** `PlanGenerationView(mode: .firstPlan | .regenerate)`
**State:** `@Observable PlanGenStore` with one state property:

```swift
enum PlanGenState {
    case streaming(checkpoints: [String], text: String, attempt: Int)
    case done(Workout)        // already-saved Workout entity
    case failed(error: Error)
}
```

### Stream consumption

`PlanGenerationView` enters in `.streaming(checkpoints: [], text: "", attempt: 1)` and immediately calls the stream provider on `PlanRepository`. Consumes the `AsyncThrowingStream<PlanGenEvent>` and applies these transitions:

| Event | Transition |
|---|---|
| `.checkpoint(label)` | append to `checkpoints[]` |
| `.text(chunk)` | append to `text`, then trim from the front so only the trailing ~6 lines are visible (older content fades out via SwiftUI animation) |
| `.done(plan)` | decode `WorkoutPlan` from the final ` ```json ... ``` ` block (already done by the stream provider); persist via `WorkoutRepository.save(planID:workoutForToday:)`; transition to `.done(workout)` |
| `.failed(err)` on `attempt == 1` | silent retry as `attempt == 2` with the spec section 7 "respond with valid JSON only" prompt suffix |
| `.failed(err)` on `attempt == 2` | transition to `.failed(err)` |

The retry-once behavior matches master spec §7 "Output validation" steps 1–2. **Step 3 (bundled fallback workout) is deferred to Plan 4** — its purpose is "user can always train" but Plan 3 is non-trainable, so a fallback workout has no value yet.

### View layout (top to bottom)

1. **Voiced header** — `CoachStrings.planGenHeader[coachID]`. Same string for `.firstPlan` and `.regenerate` modes; mode is communicated via a smaller, non-voiced subtitle line ("First day" / "Today's plan")
2. **Checkpoint stack** — vertical list of `⟦CHECKPOINT⟧` markers rendered as mono SF Mono labels with a leading dot
3. **Streaming text pane** — mono, smaller weight; pinned to a fixed-height window that always shows the most recent text; older lines fade out (opacity → 0) and clip out of the window once they exceed ~6 visible lines, so the pane never grows unbounded
4. **Done state** — `WorkoutHeroCard` (DesignSystem primitive from Plan 2) slides up with title/subtitle/duration. Single CTA: "View workout" → pushes `WorkoutDetailView(workoutID:)`. Backing out returns to Home with the new workout already present.
5. **Failed state** — error card + Retry button (re-enters with `attempt: 1`) + secondary "Back to home" link

### Voiced surfaces (counts toward the 12-string budget)

- `CoachStrings.planGenHeader[coachID]` (×4)
- The done-state hero card subtitle is **not** separately voiced — it pulls from the model-generated `why` field of the plan payload, which is already in the coach's voice via the system prompt

---

## 6. Home Feature

**Module:** `Packages/Features/Home`
**Public surface:** `HomeView`
**State:** `@Observable HomeStore` with one observed property: `todaysWorkout: Workout?`. Reads via `PlanRepository.latestWorkout()`. Refreshed on `.task` and on dismissal of the regenerate `.fullScreenCover`.

### Layout (top to bottom)

1. **Voiced greeting bar** — `"\(CoachStrings.homeGreeting[coachID]), \(profile.displayName)"`. ~4 strings, one per coach.
2. **Today's workout hero** — `WorkoutHeroCard`: title, subtitle, duration, intensity pill, "View workout" CTA → pushes `WorkoutDetailView`. Per Q6, this is the latest Workout regardless of `scheduledFor` date — no staleness logic
3. **Week strip** — 7 day chips (Mon–Sun, today highlighted). Each chip marked filled or empty based on whether a Workout exists with that `scheduledFor`. In Plan 3 only today's chip is filled; chips are decorative-only (not tappable)
4. **Regenerate CTA** — secondary tertiary-styled "Regenerate today's plan" → presents `PlanGenerationView(mode: .regenerate)` as `.fullScreenCover`. On success, the new Workout replaces the hero. Implementation: regeneration deletes the prior Workout (and its parent Plan if no other Workout references it) before saving the new one. This is safe in Plan 3 because no `Session` yet references any `Workout`. Plan 4 will need to revisit this rule once sessions exist (likely: keep prior Workouts, mark the new one current via a `supersedes` link).

### Empty state (defensive)

If `Profile` exists but no `Workout` (shouldn't happen because Q2 auto-kicks PlanGen during onboarding, but possible if PlanGen failed twice and the user backed out), the hero is replaced with a "Generate today's workout" CTA that opens `PlanGenerationView(mode: .firstPlan)`.

### Deferred to Plan 4

- Weekly ring (progress toward `weeklyTargetMinutes`) — needs `Session` data
- Week-strip status indicators (completed / skipped / in-progress) — needs `Session` data

The strip in Plan 3 has only "scheduled" and "empty" states.

---

## 7. WorkoutDetail Feature

**Module:** `Packages/Features/WorkoutDetail`
**Public surface:** `WorkoutDetailView(workoutID: UUID)`
**State:** `@Observable WorkoutDetailStore` holds the resolved `Workout` plus `[exerciseID: ExerciseAsset]` for thumbnail/video resolution. Loads on `.task`. Asset lookups are best-effort; missing IDs degrade to placeholder.

### Layout (vertical scroll)

1. **Hero header** — title, subtitle, three pills (duration / intensity 1–5 / workout type)
2. **"Why this workout" card** — renders the LLM-generated `why` string from the plan payload. Already coach-voiced (no separate `CoachStrings` lookup needed — the model wrote it under the coach's system prompt)
3. **Blocks list** — vertical sections per block (Warmup / Main / Cooldown). Each block has a section header + a list of exercise rows
4. **Exercise row** — thumbnail (poster jpg from R2 via `ExerciseAssetRepository`), name, target prescription ("3 × 8 @ RPE 8" / "0:30"), trailing "i" icon-button. Tapping the row or "i" presents `ExerciseDetailSheet` (looping MP4 + cleaned-up instructions)
5. **Bottom Start CTA** — disabled `Button` styled as primary CTA with subtitle "Coming in the next update". Tapping does nothing. Plan 4's task list will swap in the wire-up to `InWorkoutView`

### Asset resolution

Each exercise row resolves its `ExerciseAsset` via `ExerciseAssetRepository.asset(id:)` (already shipped in Plan 2). If the LLM emitted an exercise ID not present in the manifest:
- The row falls back to `ExercisePlaceholder` (DesignSystem primitive)
- Name comes from the plan payload (the model emitted both ID and name)
- The "i" button is hidden for that row
- An OSLog warning is emitted with the unresolved ID for later prompt tuning

### Navigation in

- Pushed from Home's hero card "View workout" CTA
- Pushed from PlanGen's done-state hero card "View workout" CTA

### No new voiced surfaces

The `why` card carries personality through model-generated copy.

---

## 8. Voiced Strings Table

Lives in `Packages/CoreModels/CoachStrings.swift`. ~12 strings total (4 coaches × 3 surfaces).

```swift
public enum CoachStrings {
    public static let onboardingWelcome: [String: String]   // step 6 confirmation
    public static let planGenHeader: [String: String]       // PlanGen view header
    public static let homeGreeting: [String: String]        // Home top bar prefix
}
```

Coach IDs: `"ace"`, `"rex"`, `"vera"`, `"mira"`. Final wording chosen during implementation; the table is small enough to tune in one sitting. Indicative targets:

- **`planGenHeader`** — "Putting your day together" (Ace) / "Building today's session" (Rex) / "Designing this for you" (Vera) / "Shaping today" (Mira)
- **`homeGreeting`** — "Hey" (Ace) / "Morning" (Rex) / "Welcome back" (Vera) / "Hi" (Mira) — rendered as `"\(greeting), \(profile.displayName)"`

(See §4 for `onboardingWelcome` example targets.)

All other UI strings (button labels, errors, navigation titles, validation messages) stay coach-neutral.

---

## 9. Cross-Cutting Concerns

### Error handling tiers

| Tier | Surface | Behavior |
|---|---|---|
| Network (worker unreachable) | PlanGen | Transition to `.failed`; retry button re-attempts the stream |
| LLM decode failure | PlanGen | Silent retry once with stricter prompt suffix per master spec §7. Second failure → `.failed` state |
| Persistence write failure | Anywhere | OSLog + generic alert "Couldn't save — try again." No auto-retry |
| Asset manifest miss | WorkoutDetail row | Degrade to `ExercisePlaceholder` with name only; OSLog warning |

No bundled fallback workout in Plan 3. Deferred to Plan 4.

### Testing strategy (Plan 2 parity)

Per-feature unit tests on the `@Observable` store + pure logic only. Targets:

- **`OnboardingStore`** — `canAdvance` per step boundary; atomic `Profile` write at completion; navigation forward/back; theme accent applied on coach pick
- **`PlanGenStore`** — state transitions for each `PlanGenEvent`; checkpoint marker extraction; decode-on-done via fixture; retry-once-then-fail; text-buffer trim
- **`HomeStore`** — `latestWorkout` fetch; empty-state branch
- **`WorkoutDetailStore`** — asset resolution; placeholder fallback for missing manifest IDs

Repositories also gain unit tests:

- **`ProfileRepository`** — save, currentProfile read, idempotency

**Sim smoke per feature:** a single `DebugFeatureSmokeView` extends Plan 2's `DebugStreamView` pattern with four entry points — each launches the feature with seeded fixture data so the slice can be eyeballed end-to-end without going through onboarding every time.

No XCUITest UI tests. No snapshot tests. Same rigor bar as Plan 2.

### Concurrency

`async/await` everywhere, matching Plan 2's pattern. Stream consumption uses `for try await event in stream` inside a `Task` tied to the view's `.task` lifecycle. All `@Observable` store mutations occur on `MainActor` (annotate the stores with `@MainActor`).

### Plan 2 deviations to remember (apply here too)

From the Plan 2 retro:

- SwiftData test methods need `@MainActor` under Swift 6 strictness
- `.copy("Fixtures")` in `Package.swift` requires `subdirectory: "Fixtures"` in `Bundle.module.url(...)` lookups
- Spec-quoted oklch reference values may be off; recalculate against the standard CSS Color 4 pipeline before checking against tokens

---

## 10. Plan 4 / Plan 5 Boundary

Explicitly out of scope for Plan 3:

- **Plan 4:** InWorkout feature, Complete feature (3-step feedback), HealthKit integration, Watch app + WatchBridge, bundled fallback workout, weekly ring, week-strip status indicators, day-N plan staleness logic
- **Plan 5:** Sentry integration, in-app debug panel, XCUITest UI tests, TestFlight prep, code signing, end-to-end manual testing pass

The Plan 3 implementation plan should land tasks for these boundary items as `// TODO: Plan 4` markers where the wire-up will occur — most notably the WorkoutDetail Start CTA — so the next plan's scope is mechanically obvious.

---

## 11. References

- **Master spec:** [`docs/superpowers/specs/2026-04-26-pulse-ai-trainer-app-design.md`](./2026-04-26-pulse-ai-trainer-app-design.md) — sections 4 (iOS structure), 7 (AI integration), 9 (data model), 12 (impl order)
- **Plan 2 implementation reference:** `docs/superpowers/plans/2026-04-27-plan-2-app-foundation.md`
- **iOS dev workflow:** `ios/README.md`
- **Design handoff:** `design_handoff_pulse_workout_app/README.md` (visual design + copy + interaction source of truth)

---

## Appendix A — Estimated Plan 3 Task Count

Provided for sizing only; the implementation plan will produce the authoritative breakdown.

| Phase | Tasks (estimated) |
|---|---|
| Repositories extensions (`ProfileRepository`, `PlanRepository.stream*`, `PlanRepository.latestWorkout`) | ~6 |
| `CoreModels` additions (`OnboardingDraft`, `PlanGenEvent`, `CoachStrings`) | ~3 |
| Onboarding feature (package scaffolding + 6 step views + store + tests) | ~14 |
| PlanGeneration feature (package scaffolding + view + store + stream consumer + tests) | ~12 |
| Home feature (package scaffolding + view + store + week strip primitive + tests) | ~10 |
| WorkoutDetail feature (package scaffolding + view + store + ExerciseDetailSheet + tests) | ~12 |
| AppShell first-run branch + tab wiring | ~4 |
| Voiced strings table + coach copy authoring | ~2 |
| Sim smoke entries (`DebugFeatureSmokeView`) | ~4 |
| Manual smoke pass + commit hygiene | ~3 |

**Total: ~70 tasks.** In line with the Plan 2 (47) and master-spec scope estimate (~55–70).
