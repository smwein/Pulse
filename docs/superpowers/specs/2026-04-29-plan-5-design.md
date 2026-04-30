# Plan 5 — Watch + HealthKit Write + Live HR + Mid-Session Resume

**Date:** 2026-04-29
**Author:** brainstormed with Claude (Opus 4.7), 2026-04-29 session
**Master spec:** `docs/superpowers/specs/2026-04-26-pulse-ai-trainer-app-design.md` §5 (Watch + HealthKit), §6 (data flow), §10 (observability)

## Scope

Plan 5 ships the Apple Watch app, the HealthKit *write* path, the WatchConnectivity bridge, the live heart-rate card on the Phone during a workout, and silent mid-session crash resume.

**Out of scope (deferred):**
- Coach voice cues, background-safe rest-timer notifications → **Plan 6**
- Sentry crash reporting, in-app debug panel, XCUITest E2E → **Plan 7**
- BT heart-rate-monitor fallback → v1.1 per master spec

**Targets:** iOS 26 (iPhone 17 Pro) / watchOS 26 (Apple Watch Series 11). Plan 5 may bump deployment targets if needed to use the modern `HKWorkoutSession` mirroring API.

---

## 1. Goals & non-goals

### Ship
- Standalone watchOS SwiftUI app with three screens: **Idle**, **Active Set**, **Rest**.
- Phone-initiated workout flow extends to push the day's payload to the Watch; Watch starts `HKWorkoutSession` and writes one `HKWorkout` to HealthKit on session end.
- Either device can mark a set done; the other reflects within ~1s. Repository writes idempotent on `setId`.
- Live heart-rate card on Phone's `InWorkoutView`, driven by mirrored `HKLiveWorkoutBuilder` data — no custom HR plumbing over WCSession.
- Silent mid-session resume after either app is force-quit / crashes mid-workout.
- Thin `Logger` infrastructure (`os.Logger` wrapper) replacing Plan 4's silent-catch sites.

### Do not ship
- Watch-initiated workout starts. The Watch Idle screen is a "waiting for phone" state.
- Set-actuals editing on the Watch — confirm-only; reps/load default to prescription, RPE captured later in the Phone Recap.
- BT HR monitor fallback when Watch is missing.
- Voice cues, rest-timer push notifications, Sentry, XCUITest.

### Success criteria
- All seven real-device smoke scenarios green on iPhone 17 Pro + AW Series 11 (§8).
- All package `swift test` suites green.
- Exactly one `HKWorkout` per completed session visible in Apple Health.
- No silent `do { } catch { }` left in repository code touched by this plan.

---

## 2. Decisions ledger (locked during brainstorming, 2026-04-29)

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | Plan 5 = Watch + HK write + WC + Live HR + Resume only | Plan 4's deferred bucket spans 8 subsystems; splitting keeps each plan close to Plan 4 size |
| 2 | Real-device smoke is the ship gate | watchOS Simulator unreliable for HKWorkoutSession + HR; user has hardware |
| 3 | Phone-initiated start only | Matches "phone in bag, watch on wrist"; Watch Idle stays trivial |
| 4 | Confirm-only set logging on Watch | Future.co-aesthetic minimal taps; actuals editable in Plan 4's Recap |
| 5 | Just-in-time HealthKit write auth on first Plan-5 workout start | No retroactive Onboarding revisit; explains *why* in context |
| 6 | Phone's `InWorkoutView` stays a live mirror — either device can log | Minimal change to Plan 4 code; user can pull phone out mid-workout |
| 7 | Silent mid-session resume on crash | Future.co "it just works" feel; happy path stays paper-cut-free |
| 8 | iOS 26 / watchOS 26 deployment targets | Both devices on latest software; unlocks `HKWorkoutSession` mirroring |
| 9 | **Approach A:** mirroring + WCSession typed messages for set-logs/payload | Mirroring handles HR + lifecycle natively; WCSession is the right tool for queued reliable set-log delivery |
| 10 | Fold the Plan 4 forward-flag `Logger` work into Plan 5 | Plan 5 is the first plan that genuinely benefits from structured logging (resume, outbox, auth-denial paths) |

---

## 3. Module layout

### New Xcode targets
- **`PulseWatch`** — standalone watchOS SwiftUI app target, paired-companion (not the deprecated extension style).
- **`PulseWatchTests`** — Watch unit-test target.

### New SPM packages (under `ios/Packages/`)
- **`WatchBridge`** — multi-platform (iOS + watchOS). Owns the `WCSession` singleton, the typed `WCMessage` envelope, Codable encode/decode, reachability state, the `MirroredSessionObserver` that bridges `HKHealthStore` mirroring callbacks to a Swift `AsyncStream`. No business logic.
- **`Features/WatchWorkout`** — watchOS-only. Three Watch screens (Idle, Active Set, Rest) + a `WatchSessionStore` actor that owns `HKWorkoutSession` + `HKLiveWorkoutBuilder`, drives the state machine, persists outbox.
- **`Logging`** — tiny multi-platform package wrapping `os.Logger` with category subsystems (`bridge`, `session`, `healthkit`, `repo`). Sentry-ready (Plan 7 plugs in a transport).

### Extensions to existing Plan 4 packages
- **`HealthKitClient`** — add `requestWriteAuthorization()` covering `HKWorkoutType`, `activeEnergyBurned`, `heartRate`. Existing read API unchanged.
- **`Features/InWorkout`** — add `LiveHRCardView` subview at the top of `InWorkoutView`; extend `InWorkoutStore` with a mirrored-builder HR observer; accept incoming remote set-log messages and apply via the same repository call as local taps.
- **`Persistence`** — start populating `SessionEntity.watchSessionUUID` (column already exists per master spec line 535). No SwiftData migration.
- **`AppShell`** — gate Plan 4's orphan-cleanup behind "no active mirrored session"; add the resume path that re-presents `InWorkoutView` when an in-progress `SessionEntity` + an active mirrored `HKWorkoutSession` are both detected on launch.
- **Repositories (across the board)** — replace silent `do { } catch { }` patterns flagged in `plan-4-forward-flags.md` (`PlanRepository.regenerate` cleanup, etc.) with `Logger.error(...)` calls.

### Watch-side persistence
- Plain JSON files in the Watch app's container:
  - `pending-set-logs.json` — outbox queue.
  - `active-workout-payload.json` — last-pushed workout, used to render Active Set immediately on relaunch before WCSession reconnects.
- No SwiftData on Watch (tooling weak; we don't need it).

---

## 4. Wire format

`WCMessage` is a single Codable envelope used across both transports.

| Variant | Direction | Transport | Notes |
|---------|-----------|-----------|-------|
| `.workoutPayload(WorkoutPayloadDTO)` | Phone → Watch | `transferUserInfo` | Queued, reliable. Sent on Start. |
| `.setLog(SetLogDTO)` | Watch → Phone | `transferUserInfo` | Queued, reliable. `SetLogDTO.setId: UUID` is the idempotency key. |
| `.sessionLifecycle(LifecycleEvent)` | Watch → Phone | `sendMessage` (with `transferUserInfo` fallback) | `started(watchSessionUUID)` / `ended` / `failed(reason)` |
| `.ack(setId)` | Phone → Watch | `sendMessage` | Optional; outbox drains on receipt or on next reachability + age threshold (whichever first). |

`WorkoutPayloadDTO` is a flattened, watch-friendly subset of `WorkoutEntity` plus its exercises (no SwiftData refs). Defined in `WatchBridge`.

---

## 5. Lifecycle paths

### A. Workout start (Phone-initiated)
1. User taps Start in `WorkoutDetailView`.
2. `InWorkoutStore.start()` checks `WCSession.isWatchAppInstalled` + `.isReachable`.
3. **Watch reachable:** Phone sends `.workoutPayload(...)` via `transferUserInfo`. Phone navigates to `InWorkoutView` and shows "Connecting to Watch…" until receiving `.sessionLifecycle(.started(uuid))`. Phone records `SessionEntity.watchSessionUUID`, registers the `HKHealthStore` mirroring start handler, switches `LiveHRCardView` to active state.
4. **Watch missing:** Plan 4 fallback path; `LiveHRCardView` shows "—".
5. Watch receives payload → starts `HKWorkoutSession` with derived `activityType` → calls `startMirroringToCompanionDevice()` → renders Active Set screen.

### B. Set log (either device)
- **From Watch:** tap "Set done" → write `SetLog` to outbox synchronously → enqueue `.setLog(...)` via `transferUserInfo` → on `didReceiveUserInfo` Phone-side, Phone applies via `SessionRepository.appendSetLog(...)`. Phone optionally returns `.ack(setId)`.
- **From Phone:** Phone applies via the same repository call directly. No echo back to Watch.
- Repository write is **idempotent on `setId`**. Both UIs observe via SwiftData `@Query` / `Observation`.

### C. Live HR (mirrored builder)
- Watch's `HKLiveWorkoutBuilder` runs as part of the mirrored session.
- Phone, having registered the mirroring start handler, gets the remote builder; `LiveHRCardView` subscribes to its data publisher.
- Display coalesces to whole BPM, smoothed over a 5s window.
- On unreachable: last-known BPM grays out for 10s → "—". On reconnect: silent resume, no alert.

### D. End + resume
- **Normal end:** Watch ends `HKWorkoutSession` on the last set's confirmation → builder writes one `HKWorkout` to HealthKit → `.sessionLifecycle(.ended)` to Phone → Phone marks `SessionEntity.endedAt`, drains outbox, navigates to Plan 4's Complete flow.
- **Watch crash:** HKWorkoutSession survives in the background. Watch app relaunch → reads `active-workout-payload.json` to render UI immediately → re-attaches to the active session via the appropriate `HKHealthStore` API (specific call resolved at implementation time — see §10) → continues. Phone never knew anything happened.
- **Phone crash:** Watch keeps running. Phone relaunch → `AppShell` checks for an in-progress `SessionEntity` AND an active mirrored session → if both, restores `InWorkoutView` and re-registers the mirroring start handler. Otherwise, Plan 4's orphan cleanup runs.
- **Both crashed:** mirroring is gone; whatever `HKWorkout` the Watch managed to write before the crash is preserved; in-flight outbox replays on next reachability. Documented as accepted loss.

---

## 6. Auth & permissions UX

### Phone HealthKit *write* auth
- **Trigger:** `InWorkoutStore.start()` checks write-auth status before pushing payload. If undetermined, present a small modal: *"Pulse needs to save your workouts to Health so the AI can adapt your plan."* → "Continue" → system prompt.
- **On denial:** workout still saves to SwiftData; `HKWorkout` write is skipped silently. Adaptation pipeline already has a SwiftData-only fallback (Plan 4).
- **No retroactive Onboarding revisit.** Existing users hit the JIT prompt on their next workout start.

### Watch HealthKit auth (separate grant — Apple's rule)
- **Trigger:** Watch app's first launch (after Phone pushes a workout payload). Before starting `HKWorkoutSession`, Watch checks status; if undetermined, requests its set; on grant, proceeds.
- **On denial:** Watch sends `.sessionLifecycle(.failed(.healthKitDenied))`. Phone falls back to no-Watch path silently and surfaces a one-time dismissable banner on Home: *"Watch declined HealthKit access — open the Watch app to enable."* No Settings screen needed in Plan 5.

### Info.plist + capabilities
- **Watch target:** `NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription` matching Phone tone. `WKBackgroundModes = workout-processing`. `HealthKit` capability. `WatchConnectivity` capability.
- **Phone target:** existing HealthKit + WC capabilities from Plan 4 confirmed; no new entitlements needed.

### WatchConnectivity activation
- `WCSession.default` activated in both `App.init`s, with delegates set first (Apple's strict ordering).
- No user-facing UX. Reachability state surfaces only as the live-HR-card "—" placeholder when watch is missing.

---

## 7. Error handling

| Scenario | Behavior |
|----------|----------|
| Watch unreachable mid-workout | `transferUserInfo` queues. Outbox replays on reconnect. HR card grays for 10s → "—". No alert. |
| HK auth denied (Phone) | SwiftData write proceeds; `HKWorkout` write skipped silently. |
| HK auth denied (Watch) | One-time dismissable Home banner. No retroactive prompts. |
| `HKWorkoutSession.startActivity` throws | `.sessionLifecycle(.failed(.sessionStartFailed))` → Phone fallback path. Logged via `Logger.session.error(...)`. |
| Watch crash | Silent resume via session re-attach. |
| Phone crash | Silent resume via `AppShell` check. |
| Both crashed | Orphan cleanup; whatever HKWorkout was written stays. Documented loss. |
| WCSession activation fails | `Logger.bridge.error(...)`. Phone behaves as if Watch is missing. |

### Logger infrastructure (Plan 4 forward-flag work, folded here)
- New `Logging` package wraps `os.Logger` with subsystem categories: `bridge`, `session`, `healthkit`, `repo`.
- Replaces silent catches called out in `plan-4-forward-flags.md` (e.g., `PlanRepository.regenerate` cleanup catch).
- This is **not** Sentry. Sentry plugs into the same `Logger` calls in Plan 7 via a transport.

---

## 8. Testing strategy

### Unit (`swift test` per package)
- **`WatchBridge`** — codec round-trip every `WCMessage` variant, outbox replay ordering, idempotent dedup. Inject a fake transport.
- **`Features/WatchWorkout`** — `WatchSessionStore` state machine: start → active → paused → ended, plus crash-recovered branch. Mock `HKWorkoutSession` behind a protocol.
- **`HealthKitClient`** — extend Plan 4's fake `HKHealthStore` for the write-auth flow.
- **`Features/InWorkout`** — live HR subscription updates `LiveHRCardView` correctly given mock mirrored-builder events; remote set-log application is idempotent with local taps.
- **`Logging`** — emission shape is correct (subsystem + category + level).

### Integration (XCTest target on iPhone simulator)
- **`PulseAppIntegrationTests`** — drive `InWorkoutStore` end-to-end with a fake `WatchBridge`: simulate workout start, inject set-log messages, assert SwiftData state. No real WCSession, no Watch sim. Fast, deterministic, runs in CI cadence.

### Real-device smoke gate (the ship contract)
Documented at `docs/superpowers/smoke/plan-5-watch-smoke.md` (created during execution). iPhone 17 Pro + AW Series 11. **All seven scenarios must pass** before push to `origin/main`:

1. **Happy path:** Phone Start → Watch joins → log every set on Watch → live HR on Phone → Watch ends → Complete flow → `HKWorkout` in Apple Health.
2. **Phone primary:** sets logged on Phone only → Watch reflects state → ends cleanly.
3. **Mixed:** alternate Watch/Phone set logging → no duplicates, all sets persisted.
4. **Watch unreachable:** Phone airplane mode mid-workout → Watch keeps logging → restore connectivity → outbox drains → HKWorkout written.
5. **Phone-quit:** force-quit Phone mid-workout → Watch keeps going → Phone relaunch → silent resume into `InWorkoutView` → finish workout cleanly.
6. **Watch-quit:** force-quit Watch app mid-workout → Watch relaunch → recover session → finish.
7. **HealthKit denial:** revoke Phone write auth → start workout → fallback engages, no crash. Repeat for Watch denial → Home banner shows.

### Out of Plan 5 testing
- watchOS Simulator HR streaming (covered by real device).
- Multi-device concurrency edge cases beyond the seven scenarios (Plan 7 QA).
- BT HR monitor fallback (v1.1).

---

## 9. Forward flags for Plan 6 / Plan 7

- The `Logging` package is intentionally Sentry-ready: in Plan 7 we add a transport that forwards `.error` and `.fault` levels to Sentry. Don't add the Sentry SDK dependency in Plan 5.
- `LiveHRCardView` placement and visual style stays minimal in Plan 5 (BPM number + zone color band). Future.co-style HR-zone visualization can be a Plan 6 polish item.
- Coach voice cues and rest-timer notifications are referenced in master spec §5 / §10 but stay deferred. The `WatchSessionStore` Rest screen is just a countdown display in Plan 5; voice/notif hooks added in Plan 6.
- The Watch app's set-log outbox is plain JSON. If Plan 6+ ever needs richer Watch-side state (offline workout history, etc.), reconsider SwiftData on Watch then — not before.

---

## 10. References & API resolution

### Internal
- Master spec: `docs/superpowers/specs/2026-04-26-pulse-ai-trainer-app-design.md` §5 (Watch + HealthKit), §6 (data flow), §10 (observability).
- Plan 4 deferral note: `docs/superpowers/plans/2026-04-29-plan-4-session-loop.md` line 13.
- Plan 4 forward flags: `plan-4-forward-flags.md` (Claude memory) — silent-catch logging gap addressed by §7.
- Plan 4 spec: `docs/superpowers/specs/2026-04-28-plan-4-design.md` (`SessionEntity.watchSessionUUID`, `HealthKitClient` shape).

### External (resolve exact API names at writing-plans / implementation time — APIs evolved across iOS 17/18/26)
- `HKWorkoutSession.startMirroringToCompanionDevice()` — companion mirroring.
- `HKHealthStore.workoutSessionMirroringStartHandler` — Phone-side mirrored-session callback.
- `HKHealthStore.recoverActiveWorkoutSession(...)` — relaunch resume helper.
- `WCSession.transferUserInfo` / `sendMessage` semantics, reachability rules.
- `WKBackgroundModes` workout-processing requirements for Watch target.
