# Pulse — Plan 4: Session Loop + Adaptation (Design)

**Status:** Draft, ready for implementation planning
**Date:** 2026-04-28
**Audience:** Solo developer; this spec scopes the iPhone-only session-and-adaptation slice that sits on top of Plan 3
**Master spec:** [`2026-04-26-pulse-ai-trainer-app-design.md`](./2026-04-26-pulse-ai-trainer-app-design.md). This document does not duplicate it; it specifies the design choices for the Plan 4 slice that the master spec leaves open.
**Predecessor:** [`2026-04-28-plan-3-features-design.md`](./2026-04-28-plan-3-features-design.md). Plan 3 shipped the cold-start → onboarding → plan-gen → workout-detail flow with a deliberately disabled Start CTA.

---

## 1. Slice Summary

Plan 4 ships the user-facing flow from "tap Start on today's workout" through "see how the AI adapted tomorrow's session":

1. **InWorkout** — data-dense session screen with state machine + inline-editable SET LOG + rest timer
2. **Complete** — 3-step feedback flow: Recap → Rate → AI Adaptation Preview
3. **Adaptation streaming** — Anthropic SSE call that returns a *new* workout for the next scheduled date, with adjustments + rationale
4. **HealthKit read** — 7-day activity / HR / HRV / sleep summaries injected into plan-gen + adaptation prompts
5. **Plan 3 carry-over fixes** — four required correctness fixes (regenerate cascade, weekStart calendar alignment, TOCTOU on workout ID, bundled fallback workout)

The slice ends with the user back on Home, where the *next* day's workout reflects the adaptation: a fresh `WorkoutEntity` has superseded the original, and the WeekStrip + hero card both read the new plan automatically.

This is the **product's defining moment**: the post-workout feedback → AI adaptation loop. The visible UX confirms "the coach saw what I felt and changed tomorrow accordingly."

**Explicitly out of scope, deferred to Plan 5:**
- Apple Watch app + WatchBridge / WCSession messaging
- HealthKit *write* (`HKWorkoutSession`, `HKWorkout` records)
- Live HR streaming card (placeholder "—" tile in Plan 4)
- Mid-session resume after force-quit (current behavior: silently abandon partial session)
- Coach voice cues mid-workout (AVSpeechSynthesizer)
- Background-safe rest-timer notifications
- Sentry / crash reporting
- XCUITest end-to-end automation

---

## 2. Locked Decisions

Answers chosen during brainstorming. Inputs to planning, not open questions.

| Area | Decision | Source |
|---|---|---|
| Plan 4 scope | iPhone session loop + Complete + adaptation + HealthKit *read* + Plan 3 carry-overs. Watch + HK *write* deferred to Plan 5. | Q1-B + Q5-B |
| Smoke test | Minimal vertical slice: cold start → onboarding → plan gen → tap Start → log every set → 3-step Complete → adaptation streams → next workout reflects. No HR card, no resume, no voice cues. | Q2-A |
| SET LOG interaction | Pre-filled, inline-editable per row. Reps stepper, load stepper (+/− 5kg with long-press for free-form text), RPE 1–10 dot picker. | Q3-B |
| Adaptation behavior | LLM returns a *full new workout* for the next scheduled date. Old workout marked `status="superseded"`; new workout inserted; all under one transaction. | Q4-B |
| HealthKit read in Plan 4 | Yes. `HealthKitClient` package implemented; 7-day summaries injected into plan-gen + adaptation prompts. | Q5-B |
| HK permission timing | New onboarding step 7 "Connect Apple Health" between coach pick (step 6) and plan-gen handoff. Touches Plan 3's shipped onboarding flow. | Q6-A |
| Plan 3 carry-overs | Four blockers required (regenerate cascade, weekStart calendar, TOCTOU on workout ID, bundled fallback). Four cleanups optional in skippable Phase 0. | Q7 |
| Mid-session exit | Confirmation alert "Discard workout?" → on Discard: cascade-delete `SetLogEntity` rows, delete `SessionEntity`, restore `Workout.status = "scheduled"`. No partial-save, no jump-to-Complete. | Q8-A |
| Implementation strategy | Risk-first: Plan 3 cleanups (optional) → blockers + bundled fallback → HealthKit + onboarding → repos → InWorkout → Complete steps 1/2/3 → AppShell wiring + smoke. | Approach 1 |
| Testing | Match Plan 3: extensive unit tests on data + business layers, manual smoke for UI integration. No XCUITest. | §6 below |
| Adjustments source | LLM-supplied (one event per adjustment in the SSE stream). Client never derives adjustments from feedback rules. | Design handoff README explicit guidance |

---

## 3. Module Layout

Plan 4 adds two feature packages and substantially extends three infrastructure packages. Existing entities in `Persistence` are wired into use for the first time.

```
PulseApp (target)
└── AppShell                                    ← Plan 2 (extended)
    ├── Features/Onboarding         ← Plan 3 (extended: +1 step)
    ├── Features/Home               ← Plan 3 (extended: filter superseded)
    ├── Features/PlanGeneration     ← Plan 3 (extended: HK summaries in prompt)
    ├── Features/WorkoutDetail      ← Plan 3 (extended: enable Start CTA)
    ├── Features/InWorkout          ← NEW (Plan 4)
    └── Features/Complete           ← NEW (Plan 4)
                                    │
                                    ├── Repositories         ← Plan 3 (extended + 3 new repos)
                                    ├── HealthKitClient      ← Plan 2 (implemented for first time)
                                    ├── Networking            ← Plan 2 (unchanged; SSEStreamParser reused)
                                    ├── Persistence           ← Plan 2 (entities wired into use)
                                    ├── DesignSystem          ← Plan 2 (unchanged)
                                    └── CoreModels            ← Plan 3 (extended)
```

### Per-package work summary

| Package | Plan 4 work |
|---|---|
| `CoreModels` | `WorkoutFeedback`, `SetLogEntry`, `AdaptationDiff` already present + tested in Plan 2. Add `AdaptationStreamEvent` enum (parallel to Plan 3's `PlanGenStreamEvent`). |
| `Persistence` | Entities already exist (`SessionEntity`, `SetLogEntity`, `FeedbackEntity`, `AdaptationEntity`). Wire into actual use. Extend `WorkoutEntity.status` semantics: `"scheduled" / "in_progress" / "completed" / "superseded"` (mid-session discard restores to `"scheduled"`, no `"abandoned"` state). Add `transaction { @MainActor ... }` helper for multi-write atomicity. |
| `Networking` | `SSEStreamParser` reused unchanged — adaptation stream uses the same checkpoint pattern. Add adaptation endpoint URL constant. |
| `HealthKitClient` | Currently empty package. Implement: `requestAuthorization`, `sevenDayActivitySummary`, `sevenDayHRSummary` (resting HR + HRV SDNN), `sevenDaySleepSummary`. Read-only. Protocol-injected `HKHealthStore` for unit tests. |
| `Repositories` | New: `SessionRepository`, `FeedbackRepository`, `AdaptationRepository`. Modify: `PlanRepository` (regenerate cascade fix, weekStart calendar fix, supersedes-workout insertion). Modify: `WorkoutRepository` (`latestWorkout()` filters superseded; new `workoutForDate(_)`). Modify: `PromptBuilder` (HK summary block, adaptation prompt builder). Modify: `onPersistedWorkout` callback signature to receive stable `WorkoutEntity.id`. New: `BundledFallback.todayWorkout(profile:)`. |
| `Features/Onboarding` | Insert step 7 "Connect Apple Health" between coach pick (step 6) and plan-gen handoff. Add Connect / Skip options. Calls `HealthKitClient.requestAuthorization` on Connect. Skip is non-destructive — plan-gen still runs without HK summaries. |
| `Features/PlanGeneration` | Read HK summaries from `HealthKitClient` and pass to `PromptBuilder`. Add re-entry guard on `PlanGenStore.run` (Plan 3 carry-over #6). |
| `Features/Home` | Read latest non-superseded workout. WeekStrip filters superseded rows when computing per-day status. |
| `Features/InWorkout` | New SPM package. `SessionStore` (`@Observable`) state machine; data-dense layout (top bar + progress segments + exercise card + live metrics grid w/ HR placeholder + SET LOG card w/ inline editors + bottom controls); rest-phase view; rest auto-advance; `UIApplication.isIdleTimerDisabled` lifecycle; close-button confirmation alert → discard path. |
| `Features/Complete` | New SPM package. Three subviews (Recap / Rate / Adaptation) + `CompleteStore`. Submit flow: persist `FeedbackEntity` → start adaptation stream → on done run supersedes-workout transaction → render result. |
| `AppShell` | Enable `Start` CTA on `WorkoutDetailView` (currently disabled). Wire fullScreenCover sequence: `WorkoutDetail.Start` → `InWorkout` → on `.completed` → `Complete` → on done → dismiss to Home. Add InWorkout + Complete entry points to `DebugFeatureSmokeView`. |

**Total new code surface estimate:** ~3,000–3,500 LOC across ~80 files. Slightly larger than Plan 3 (~2,900 LOC / 68 files); the extra is mostly the InWorkout state machine, Complete's three-step flow, and the `HealthKitClient` implementation.

---

## 4. Data Flow — The Working Spine

The single most important pipeline in Plan 4. Tracing from "user taps Start" to "next workout reflects adaptation":

### Phase A — Session start

1. User taps Start CTA on `WorkoutDetailView` (currently disabled; Plan 4 enables).
2. `AppShell` presents `InWorkoutView` via `.fullScreenCover`. No confirmation modal — direct dive.
3. `SessionStore.start(workout:)` creates a `SessionEntity` with `id`, `workoutID`, `startedAt = now`, `completedAt = nil`. Persists immediately. Sets `WorkoutEntity.status = "in_progress"`.
4. `UIApplication.shared.isIdleTimerDisabled = true` so the screen doesn't sleep mid-set.

### Phase B — Set logging loop

1. `SessionStore` exposes `idx`, `setNum`, `phase` (`.work` / `.rest`), `secs`, current exercise's prescribed `reps`/`load`, and a draft `SetEntry { reps, load, rpe }` pre-filled with the prescription (RPE blank).
2. User edits values inline:
   - **Reps:** stepper around prescribed value
   - **Load:** stepper at 5kg increments around prescribed value, long-press to enter free-form text (e.g. "BW", "0:30")
   - **RPE:** 1–10 dot picker (RPE is strictly user-set; LLM never prescribes)
3. User taps "Log set N" → `SessionRepository.logSet(sessionID, exerciseID, setNum, reps, load, rpe)` writes a `SetLogEntity` row, idempotent on `(sessionID, exerciseID, setNum)` per spec §9 (fetch-then-update or insert).
4. `SessionStore` advances: `setNum++` if more sets remain, else `idx++` and `setNum = 1`. Transitions `phase = .rest`, resets `secs = 0`.
5. Rest timer auto-advances back to `.work` when `secs >= ex.rest`. **Foreground-only in Plan 4** — backgrounded apps stop the timer; on foreground, `secs` is recomputed from wall-clock delta. Background notifications deferred to Plan 5.
6. After last set of last exercise → `SessionStore.finish()` → `Session.completedAt = now`, `Workout.status = "completed"`, dismisses InWorkout, presents Complete.

### Phase C — Mid-session exit (safety valve)

User taps close (X) → confirmation alert "Discard workout?" → on Discard: `SessionRepository.discardSession(id)` cascade-deletes the `SetLogEntity` rows, deletes the `SessionEntity`, restores `Workout.status = "scheduled"`. Dismisses to Home. (No partial-save, no jump-to-Complete.)

### Phase D — Complete: Recap

`CompleteView` reads the just-finished `SessionEntity` + `SetLogEntity` rows + parent `WorkoutEntity`. Renders the cinematic recap (TIME / AVG-HR / KCAL / VOL stat tiles). HR and KCAL show "—" in Plan 4 since no `HKWorkout` write yet; TIME is `Session.durationSec`; VOL is computed client-side from logged sets (sum of `reps × load` where load parses to a numeric kg).

### Phase E — Complete: Rate

Local `CompleteStore.feedbackDraft: WorkoutFeedback` collects: `rating`, `intensity`, `mood`, `tags`, `exRatings` (per-move thumbs for first 4 exercises), optional `note`. "Send to {Coach} →" disabled until `rating > 0`. On tap → `FeedbackRepository.save(draft, sessionID:)` writes `FeedbackEntity` linked to Session → transition to Step 3.

### Phase F — Complete: Adaptation streaming

1. `AdaptationRepository.streamAdaptation(feedback:, currentWorkout:, recentSummaries:)` opens SSE to `pulse-proxy/adapt`.
2. Worker proxies to Anthropic with system prompt (cached) + user message containing the next scheduled `Workout` payload + `WorkoutFeedback` JSON + 7-day HK summaries + the locked exercise catalog.
3. LLM streams `⟦CHECKPOINT⟧` lines (mono console "thinking" lines per design handoff prototype) → `event: adjustment` events for the adjustments list (max 4) → `event: workout` event with the full new `Workout` payload for the next scheduled date → `event: rationale` with a coach-voice summary line → `event: done`.
4. On `done`: in a single SwiftData transaction, persist the `AdaptationEntity` (with `diffJSON = { adjustments[], rationale, originalWorkoutID, newWorkoutPayload }`), mark the original `WorkoutEntity.status = "superseded"`, insert a fresh `WorkoutEntity` for the same `scheduledFor` date with `status = "scheduled"`.
5. UI renders: adjustments list (LLM-supplied) + coach card (rationale) + next-session preview pulled from the just-inserted new workout.
6. "Done — see you Wednesday" dismisses to Home. Home reads `WorkoutRepository.latestWorkout()` which now returns the new (non-superseded) workout.

### The "latest non-superseded" rule

Q4-B's display-side cost. `WorkoutRepository.latestWorkout()` filters `status != "superseded"` and orders by `scheduledFor` desc. New `WorkoutRepository.workoutForDate(_)` takes a date, returns the latest non-superseded for that date. WeekStrip and Home hero both go through these — no callers see superseded rows.

---

## 5. Adaptation Contract (LLM I/O)

The single LLM call that powers the post-workout loop. Same SSE infrastructure as Plan 3 plan-gen, different prompt + output schema.

### System prompt (cached via `cache_control`)

- Coach personality block (reuse from plan-gen, varied by `Profile.activeCoachID`)
- Locked exercise catalog (reuse from plan-gen — up to 50 sampled IDs filtered by Profile equipment)
- Output format spec: stream of `⟦CHECKPOINT⟧` mono lines, then events `adjustment` × N (≤4), then `workout` (full Workout JSON for one date), then `rationale` (coach-voice 1-sentence summary), then `done`.
- Prompt body: "You are adapting tomorrow's session in response to today's feedback. Output ONE replacement workout for the next scheduled date. Adjustments list is for the user; rationale is the coach's voice. Both must reflect the actual changes you made."

### User message structure (per request)

```
SCHEDULED NEXT SESSION (to replace):
{ next WorkoutEntity payload as JSON }

JUST-COMPLETED SESSION:
- workout: { title, type, durationMin }
- sets logged: [{ exId, setNum, reps, load, rpe }, ...]
- duration: 42:18

USER FEEDBACK:
- rating: 4/5
- intensity: 4/5 (felt tough)
- mood: good
- tags: [too_long, more_strength]
- per-exercise: { ex_id_1: up, ex_id_2: down, ... }
- note: "..."

7-DAY HEALTH SUMMARY (Apple Health):
- avg resting HR: 58 bpm
- avg HRV (SDNN): 52 ms
- avg sleep: 7.4 hrs
- weekly active minutes: 187 / 240 target

EQUIPMENT: dumbbells, bench, mat
GOAL: build strength, mobility
LEVEL: regular
```

### Output stream events

| Event | Payload | Notes |
|---|---|---|
| `checkpoint` (text) | `⟦CHECKPOINT⟧ reading 1 session log` | Free text streaming for "thinking" UI; same parser as Plan 3 plan-gen |
| `adjustment` | `{ id, label, detail }` × ≤4 | One emit per adjustment. `label` ~3 words, `detail` ~6–10 words |
| `workout` | full `Workout` JSON | Same shape as plan-gen output's per-day workouts. Reused decoder. |
| `rationale` | `{ text }` | One sentence, coach voice. Renders in Step 3's coach card. |
| `done` | `{}` | Triggers persistence transaction |
| `error` | `{ code, message }` | Maps to retry-once-then-fail |

### Why LLM-supplied adjustments

The design handoff README explicitly flags client-side derivation as prototype-only: *"in production, this should be: 1. Submit `WorkoutFeedback` to the planning service ... 2. Display the adjustments returned by the planner."* Adjustments must reflect what the LLM actually did to the workout. Computing them client-side from feedback alone would lie when the LLM ignores or contradicts a tag. LLM-supplied adjustments can also be richer than the prototype's static rules (e.g. "Replacing 3 of 9 moves with bilateral variants" — too specific for client logic).

### `recentSummaries` (HealthKit read)

- Computed once per request from `HealthKitClient` 7-day window ending now.
- If HK auth was denied at onboarding → omit the `7-DAY HEALTH SUMMARY` block from the user message entirely. `PromptBuilder` handles optional blocks already (Plan 3 pattern).
- Same path used by plan-gen prompt for first plan and regenerates.

### Decoding strategy

- `AdaptationStreamEvent` enum mirrors `PlanGenStreamEvent` from Plan 3.
- Decoder validates each `workout` event against the existing `Workout` Codable schema — same validator used by plan-gen, so any drift gets caught uniformly.
- Catalog-id constraint enforced post-decode: every `exerciseID` in the workout must exist in the local `ExerciseAsset` table, else treat as malformed → bundled fallback path.

### Adaptation prompt budget

Per master spec §7: ~16 calls/mo × ~$0.10 = $1.60. Opus 4.7 with cached system prompt. Negligible.

---

## 6. Error Handling

Plan 4's failure surface, mapped to master spec §10's three tiers.

### Tier 1 — Network / LLM outages (recoverable, common)

| Failure | Behavior |
|---|---|
| Adaptation SSE drops mid-stream | Retry once with 1s backoff. On second failure, toast "Couldn't get an adaptation — your feedback is saved, we'll try again next session." `Adaptation` row not written. Original next workout stays `scheduled`. User dismisses to Home. |
| Adaptation API unreachable (no network) | Same as above. `FeedbackEntity` is already persisted (Phase E happens before the network call), so feedback is never lost. |
| Plan-gen API unreachable on first run | Plan 3 already handles; no change. |
| HK fetch fails (rare — system-level error) | Omit the `7-DAY HEALTH SUMMARY` block, log error to debug entity, continue with the prompt. Don't surface to user — HK summaries are an enrichment, not a requirement. |
| Set log write fails (SwiftData throw) | Inline banner: "Couldn't save this set — tap to retry." Disable advance/rest until retry succeeds. Set logs are the user's actual work — never silently drop. |

### Tier 2 — Malformed LLM output (rare, must catch)

| Failure | Behavior |
|---|---|
| Adaptation `workout` event fails Codable decode | Treat as malformed. Log raw payload. Trigger bundled fallback path. |
| Adaptation `workout` references unknown exercise IDs | Same as above. |
| Plan-gen returns malformed JSON | Plan 3's existing one-silent-retry-with-stricter-prompt → if still bad, fall back to bundled workout. Plan 4 implements the bundled fallback (deferred from Plan 3). |
| Bundled fallback trigger | `BundledFallback.todayWorkout(profile:)` returns a hand-authored `Workout` payload: 25-min mobility flow, 4–5 conservative moves all from the catalog (cat-cow, world's-greatest-stretch, glute-bridge, dead-bug, hip-90-90 — IDs verified at build time). Inserted into SwiftData like any other workout, with a `source = "bundled"` marker. Adjustments list shows a single card "Keeping things steady today." |

### Bundled fallback implementation details

- Lives in `Repositories/Sources/Repositories/BundledFallback.swift`
- Static `Workout` payload as Swift literal, not JSON-from-bundle (safer than missing-resource bugs)
- Build-time test verifies every exercise ID exists in a fixture catalog manifest
- Used in two cases: (a) plan-gen JSON malformed after retry, (b) adaptation JSON malformed after retry

### Tier 3 — Crashes / data corruption (must not lose state)

| Failure | Behavior |
|---|---|
| App crashes / force-quits mid-session (Plan 4 explicitly defers resume) | `SetLogEntity` writes are persisted synchronously per-set on `mainContext`, so the DB is never in a torn state — but Plan 4 does not restore the in-flight session. On relaunch, `FirstRunGate` detects an in-progress `SessionEntity` (`completedAt == nil` and `Workout.status == "in_progress"`) → cascade-deletes the partial `SetLogEntity` rows, deletes the `SessionEntity`, restores `Workout.status = "scheduled"`. User lands on Home as if nothing happened. **No restore-mid-set in Plan 4** (Plan 5 picks this up alongside the Watch's `HKWorkoutSession` resume). |
| Supersedes-workout transaction half-applied | Wrap in a single `mainContext.transaction { ... }` block. `Persistence` package adds a `transaction { @MainActor ... }` helper. Either both writes succeed (old marked `superseded`, new inserted) or both roll back. Tested via injected SwiftData failure. |
| Cascade delete on regenerate fails | New `PlanRepository.regenerate` is wrapped in a transaction: delete all `WorkoutEntity` for the prior `PlanID` + delete the `PlanEntity` + insert new ones, all-or-nothing. Carry-over #1 fix. |
| `(sessionID, exerciseID, setNum)` collision (replay) | `SessionRepository.logSet` does fetch-then-update; existing rows get overwritten with the new values. No duplicate rows. |
| HealthKit auth revoked between session and adaptation | Read returns nil/empty arrays. Treated as "no data" → omit summary block. No user-facing error. |

### Loose ends explicitly *not* handled in Plan 4

- Mid-session resume → Plan 5
- Background-safe rest-timer notifications → Plan 5
- Adaptation-failed retry queue ("queue retry on next app open" per master spec) → Plan 5 with telemetry
- Sentry / crash reporting → Plan 5

---

## 7. Plan 3 Carry-Overs

Eight items surfaced during the Plan 3 final cross-branch review. Plan 4 must address the four blockers; the four cleanups are bundled into a skippable Phase 0.

### Required for Plan 4 to work correctly (blockers)

1. **`PlanRepository.regenerate` cascade.** Currently deletes only the latest `WorkoutEntity`. Plan 4 introduces `Session` rows that reference workouts — orphaning siblings becomes data corruption. Fix: cascade-delete all of a plan's workouts in a transaction. The supersedes-workout pattern from Q4-B partially solves this for adaptation; regenerate still needs cascade for the multi-day case.
2. **`weekStart` calendar mismatch.** Plan-gen derives weekStart with Gregorian (Sunday-based); Home/WeekStrip uses ISO8601 (Monday-based). Plan 4 introduces session-week comparisons (e.g. "this week's volume" feeding the adaptation prompt) — must align. Fix: ISO8601 throughout.
3. **`onPersistedWorkout` TOCTOU.** Reads `latestWorkout()` after persist instead of using the `WorkoutPlan` argument. Works only because `mainContext` writes are synchronous — fragile. Plan 4 threads workout IDs into Sessions, so the stable ID is needed at persist time anyway. Fix: callback receives `WorkoutEntity.id` directly.
4. **Bundled fallback workout.** Master spec §10 Tier 2 mandates this; deferred from Plan 3 with a TODO. Required if Plan 4 exposes the Start CTA — without a fallback, an LLM JSON failure on the very first run dead-ends the user. Implementation detail in §6 above.

### Cleanups, not blockers (Phase 0, skippable)

5. `#Predicate` parameter capture pattern in `WorkoutRepository.markCompleted` and `WorkoutRepository.deleteWorkout`. Works on macOS 14 / iOS 17 SwiftData but brittle against future macro changes. Fix: align with `ProfileRepository.save`'s local-alias pattern.
6. `PlanGenerationView.task` re-entry guard. Plan 4 doesn't add new entry points but cheap to add. Fix: `.task(id:)` keyed on a re-run nonce, or re-entry flag in `PlanGenStore.run`.
7. `strictRetry` flag wired through `PromptBuilder` but never actually used on the retry attempt. Fix: thread the flag through `StreamProvider` and use it on the retry call.
8. `ProfileRepository.currentProfile` returns nil silently on fetch error (uses `try?`). Asymmetric with other repos. Fix: throwing fetch.

---

## 8. Testing Strategy

Match Plan 3's bar: extensive unit tests on the data + business layers, manual smoke test for UI integration. No XCUITest in Plan 4 (deferred to Plan 5 with TestFlight prep).

### Unit tests (Swift Package tests, run on every plan-execute commit)

| Layer | Coverage |
|---|---|
| `SessionRepository` | `start(workout:)` creates session w/ correct linkage; `logSet(...)` is idempotent on `(sessionID, exerciseID, setNum)` — second call updates instead of inserts; `finish(sessionID:)` sets `completedAt` + flips `Workout.status`; `discardSession(id:)` cascade-deletes SetLogs + restores Workout to `scheduled` |
| `FeedbackRepository` | `save(draft, sessionID:)` writes `FeedbackEntity` with correct `Session` relationship; idempotent on `sessionID` (prevents double-submit); rejects empty `rating == 0` |
| `AdaptationRepository` | Decode fixture: a recorded SSE byte stream of a complete adaptation flow → emits expected events in order; `persistAdaptation(_:)` runs in a transaction (test injects a write failure mid-transaction → asserts rollback); supersedes-workout flow: old marked `superseded`, new inserted, both atomic |
| `PlanRepository.regenerate` cascade fix | Setup with a Plan + 7 Workouts → `regenerate` → all 7 deleted, prior PlanEntity deleted, new ones inserted; no orphans |
| `PlanRepository.streamFirstPlan` weekStart fix | Asserts ISO8601 (Monday-based) calendar produces the same week-start as `Home.WeekStripView` for any Tuesday/Wednesday/Sunday input |
| `WorkoutRepository.latestWorkout()` / `workoutForDate(_)` | Asserts superseded rows filtered out; ordering correct when multiple non-superseded for one date |
| `PromptBuilder.adaptationUserMessage(...)` | Snapshot of formatted output for fixture inputs (feedback + workout + summaries); separate snapshot for "HK summaries omitted" path |
| `HealthKitClient.sevenDay*Summary` | Protocol-injected fake `HKHealthStore` returning fixture samples → asserts averages computed correctly; auth-denied → returns nil/empty |
| `BundledFallback.todayWorkout(profile:)` | Returns a valid `Workout` decodable; every `exerciseID` in the payload exists in the bundled fixture catalog manifest (build-time guarantee) |

### State machine tests (pure logic, no UI)

| Layer | Coverage |
|---|---|
| `SessionStore` | Start state correct; `logSet` advances `setNum`; advancing past last set transitions to `.rest`; rest auto-advance back to `.work` when `secs >= ex.rest`; finish on last-set-of-last-exercise emits `.completed` lifecycle event; mid-session `discard()` resets store + emits `.discarded` event |
| `CompleteStore` | Step 1 → 2 → 3 navigation; "Send to Coach" disabled until `rating > 0`; thumbs are mutually exclusive within a row + tappable to clear; submit triggers feedback persist + adaptation stream start |

### Manual smoke test (final acceptance)

Single end-to-end run on iPhone 17 Pro Sim, fresh data:

1. Cold start → 7-step onboarding (incl. Connect Apple Health — run both grant and deny paths)
2. Plan generates → see today's workout on Home
3. Tap Start → InWorkout opens
4. Log every set across all exercises (mix of prescription-default and edited values; vary RPE)
5. After last set → Complete Step 1 (Recap) → Step 2 (Rate, fill all fields) → Step 3 (Adaptation streams)
6. See adjustments list + rationale + next-session preview
7. "Done — see you Wednesday" dismisses to Home
8. Home now shows the *new* (non-superseded) workout for tomorrow
9. Tap Regenerate → confirm full prior-plan cascade-delete works
10. Force-quit mid-session test: Start → log 1 set → kill app → relaunch → land on Home (session abandoned silently)
11. Bundled fallback test: rig the worker to return malformed JSON twice → confirm fallback workout appears + is usable

### Test fixtures added in Plan 4

- `Fixtures/AdaptationStream-success.txt` — recorded SSE of a clean adaptation
- `Fixtures/AdaptationStream-malformed.txt` — recorded SSE with a bad `workout` event
- `Fixtures/HKSamples-7day.json` — synthetic HKHealthStore samples for unit tests
- Existing `Fixtures/Catalog.json` from Plan 3 (no change)

### Explicitly NOT tested in Plan 4

- Live HK device behavior (auth re-prompts, simulator quirks) — manual sim only
- SwiftUI view rendering (Plan 5 introduces snapshot tests if XCUITest doesn't cover it)
- Watch / WatchBridge (whole subsystem deferred to Plan 5)
- Real LLM round-trips in CI (use recorded fixtures; live LLM only in manual smoke)

---

## 9. Phase Breakdown (Implementation Strategy)

Approach 1 (risk-first): foundations land before features. Each phase is one PR-sized chunk; subagent-driven execution will turn each into discrete tasks. Smoke test runs at the end of Phase 8.

| # | Phase | Goal | Key deliverables |
|---|---|---|---|
| **0** | **Plan 3 cleanups** *(optional, skip if Plan 4 capacity tight)* | Address the 4 non-blocker carry-overs while context is fresh | `#Predicate` parameter capture aligned across repos; `PlanGenerationView.task(id:)` re-entry guard; `strictRetry` flag plumbed (or removed); `ProfileRepository.currentProfile` throwing fetch |
| **1** | **Plan 3 blocker fixes + bundled fallback** | Make Plan 4's foundations sound | `PlanRepository.regenerate` cascade transaction; `weekStart` calendar alignment to ISO8601 throughout; `onPersistedWorkout` callback receives stable `WorkoutEntity.id`; `BundledFallback.todayWorkout(profile:)` static workout w/ catalog-id build-time test |
| **2** | **HealthKit read + onboarding step** | Get HK summaries flowing into prompts | `HealthKitClient` implementation (`requestAuthorization`, 7-day activity / HR / sleep summarizers); fake `HKHealthStore`-injected unit tests; Onboarding step 7 "Connect Apple Health" inserted before plan-gen handoff; `PromptBuilder.planGenUserMessage` extended with optional HK summary block; `Info.plist` `NSHealthShareUsageDescription`; HealthKit Capability added to target |
| **3** | **Session / Feedback / Adaptation repositories** | All persistence wiring for Plan 4's spine | `SessionRepository` (start / logSet idempotent / finish / discard); `FeedbackRepository` (save idempotent on sessionID); `AdaptationRepository` (streamAdaptation + persistAdaptation transaction); `WorkoutRepository.latestWorkout` filters superseded; new `WorkoutRepository.workoutForDate(_)`; `PromptBuilder.adaptationUserMessage`; `AdaptationStreamEvent` enum + parser using `SSEStreamParser`; full unit + fixture tests |
| **4** | **InWorkout feature package** | The data-dense session screen | New `Features/InWorkout` SPM package; `SessionStore` (`@Observable`) state machine; data-dense layout (top bar + progress segments + exercise card + live metrics grid w/ HR placeholder + SET LOG card w/ inline editors + bottom controls); rest-phase view; rest auto-advance; `UIApplication.isIdleTimerDisabled` lifecycle; close-button confirmation alert → discard path; `SessionStore` unit tests |
| **5** | **Complete: Recap (Step 1)** | Cinematic recap screen | New `Features/Complete` SPM package; Step 1 view (full-bleed gradient, stat tiles w/ "—" for HR/KCAL, coach card); reads `SessionEntity` + `SetLogEntity` + parent `WorkoutEntity` |
| **6** | **Complete: Rate (Step 2)** | Feedback capture form | Step 2 view (5-star rating, intensity slider 1–5, mood 2×2, per-move thumbs for first 4 exercises, quick tag pills, optional note); `CompleteStore` feedback draft state; "Send to {Coach}" CTA disabled until `rating > 0`; submit triggers `FeedbackRepository.save` then transitions to Step 3 |
| **7** | **Complete: Adaptation (Step 3)** | The product's defining moment | Step 3 view (thinking phase w/ checkpoint console, then result phase w/ adjustments list + coach card + next-session preview); wires `AdaptationRepository.streamAdaptation` → on `done` runs supersedes-workout transaction → re-reads next workout for preview card; retry-once-then-fail; bundled-fallback path on malformed-after-retry |
| **8** | **AppShell wiring + smoke test** | Tie everything together | Enable `Start` CTA on `WorkoutDetailView`; fullScreenCover sequence (InWorkout → Complete → dismiss); `DebugFeatureSmokeView` adds InWorkout + Complete entry points; manual smoke test pass on iPhone 17 Pro Sim (the 11-step protocol from §8); fixes any integration regressions |

### Dependencies

- Phase 0 is independent (skippable); doesn't block anything.
- 1 → 2 → 3 (foundations stack cleanly)
- 3 → 4 (InWorkout needs `SessionRepository`)
- 3 → 7 (Adaptation Step 3 needs `AdaptationRepository`)
- 4 → 5, 5 → 6, 6 → 7 (Complete steps build on each other UX-wise)
- 7 → 8 (final wiring needs the full Complete flow)
- Phases 0, 1, and 2 are roughly parallelizable across subagents; 3–8 are mostly sequential.

### Estimated phase sizes

Plan 3's 30 tasks split across 8 phases as the calibration baseline.

| Phase | Tasks |
|---|---|
| 0 | ~4 (skippable) |
| 1 | ~5 |
| 2 | ~6 |
| 3 | ~8 (largest — three new repos) |
| 4 | ~7 (state machine + UI + tests) |
| 5 | ~3 |
| 6 | ~5 |
| 7 | ~6 (streaming + transaction + fallback) |
| 8 | ~3 |
| **Total** | **~47 tasks** (vs Plan 3's 30 — reflects the extra subsystem) |

---

## 10. References

- **Master spec sections most relevant:** §4 (iOS app structure), §5 (HealthKit integration — read side only in Plan 4), §7 (AI integration / adaptation prompt), §9 (data model — Session, SetLog, Feedback, Adaptation entities), §10 (error handling — three tiers).
- **Plan 3 spec:** [`2026-04-28-plan-3-features-design.md`](./2026-04-28-plan-3-features-design.md). Plan 4 builds on the same per-feature SPM pattern, the same SSE / `⟦CHECKPOINT⟧` streaming infrastructure, and the same `PromptBuilder` extensibility model.
- **Plan 3 carry-overs source of truth:** `ios/README.md` "Plan 3 carry-overs to Plan 4" section + auto-memory `plan-4-forward-flags.md`.
- **Design handoff:** `design_handoff_pulse_workout_app/README.md` — section 5 (In-Workout DATA-DENSE), section 6 (Workout Complete 3-step feedback flow), and the `WorkoutFeedback` schema in "State Management".
- **HealthKit `HKHealthStore`:** https://developer.apple.com/documentation/healthkit/hkhealthstore
- **Anthropic Messages API + streaming:** https://docs.anthropic.com/en/api/messages-streaming

---
