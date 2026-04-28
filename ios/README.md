# Pulse — iOS app

This directory contains the iOS Xcode project, watchOS target (Plan 4), and all
Swift Package modules under `Packages/`. The Xcode project itself is generated
from `Project.yml` via `xcodegen`; do not edit `PulseApp.xcodeproj` by hand.

## First-time setup

```bash
brew install xcodegen                    # one-time
./scripts/bake-secrets.sh                # generates ios/PulseApp/Secrets.swift
cd ios && xcodegen generate              # regenerate xcodeproj
open PulseApp.xcodeproj
```

## Daily loop

```bash
./scripts/bake-secrets.sh && cd ios && xcodegen generate
```

Run that any time `worker/.dev.vars` changes or after `git pull`.

## Test commands

Per-package (fast): `cd ios/Packages/<Pkg> && swift test`.

Live worker integration test (opt-in):

```bash
set -a; source worker/.dev.vars; set +a
PULSE_LIVE_TEST=1 \
  PULSE_WORKER_URL="$WORKER_URL" \
  PULSE_DEVICE_TOKEN="$DEVICE_TOKEN" \
  swift test --package-path ios/Packages/Networking --filter LiveWorkerSmokeTests
```

## Plan 2 acceptance smoke checklist

Run this once after the final task; all items must pass before declaring Plan 2 done.

- [ ] `xcodebuild -project ios/PulseApp.xcodeproj -scheme PulseApp -destination 'generic/platform=iOS Simulator' build` succeeds
- [ ] `swift test` is green in: CoreModels, DesignSystem, Persistence, Networking, Repositories, AppShell
- [ ] App launches on iOS 17+ simulator, shows the Today tab with the Pulse top bar
- [ ] Wrench icon switches to Debug tab; back button returns to Today
- [ ] Tapping ACE / REX / VERA / MIRA pills changes the accent color in real time across the app shell (top bar, tab bar selection, primary buttons)
- [ ] "Ping worker" button in Debug streams SSE events from the live worker into the mono console (look for `content_block_delta`, `message_stop`)
- [ ] Live integration test passes when run with `PULSE_LIVE_TEST=1` env vars set
- [ ] No git uncommitted changes; branch can be pushed cleanly to origin

## Plan 3 acceptance checklist

After a fresh install on the iPhone 17 Pro simulator (run `Debug → Smoke → Wipe` then force-quit + relaunch to reset to first-run state):

- [x] App opens to OnboardingFlowView (no Profile present)
- [x] All 6 onboarding steps validate before allowing Next
- [x] Coach picker swaps the accent hue immediately
- [x] On step 6 → Next, PlanGenerationView appears as a fullScreenCover
- [x] Streaming UI shows: voiced header, checkpoint rows, mono streaming text
- [x] Done state shows the WorkoutHeroCard with title pulled from the LLM-generated plan
- [x] Tapping "View workout" pushes WorkoutDetailView; navigation back returns to Home
- [x] Home shows: voiced greeting, hero card, week strip with today filled, regenerate CTA
- [x] WorkoutDetail shows: hero pills, why card, blocks list, exercise rows with thumbnails, disabled Start CTA
- [x] Tapping an exercise row opens the looping MP4 sheet with Done button
- [x] Regenerate cycle: tap regenerate → PlanGen runs → return to Home → hero updates
- [x] DebugFeatureSmokeView's "Wipe" button restores first-run state (forces re-onboarding)

### Plan 3 fixes during smoke

- Manifest URL plumbed via Secrets → AppContainer → ExerciseAssetRepository (commit `e916da0`)
- ExerciseDetailSheet gained a Done button via toolbar (commit `e916da0`)
- ExerciseAssetRepository.Entry decoder fixed to match real manifest shape (`category` not `focus`, nullable single-string `equipment`); 873 assets now load (commit `fb9c144`)
- PromptBuilder + PlanRepository extended to inject up to 50 sampled catalog IDs into the system prompt so the LLM picks valid exercise IDs (commit `fb9c144`)

### Plan 3 carry-overs to Plan 4

- `PlanRepository.regenerate` deletes only the latest WorkoutEntity, not all rows for the prior PlanEntity. Safe in Plan 3 (no Sessions reference workouts yet); Plan 4 must revisit
- `PlanGenerationView.task` is unguarded against re-entry — low risk in Plan 3 since the only entry is FirstRunGate's fullScreenCover
- `#Predicate` parameter capture pattern (parameter directly used in closure) in `WorkoutRepository.markCompleted` and `WorkoutRepository.deleteWorkout` — works on macOS 14 / iOS 17 SwiftData but should be aligned with `ProfileRepository.save`'s local-alias pattern in a future cleanup
- WorkoutDetail's exercise row info-button double-fires `onTap` (sheet deduplication makes it harmless today)
- `PlanGenStore` retry-once is cosmetic: `strictRetry` is wired through `PromptBuilder` but the captured `streamProvider` closure can't switch prompts mid-run, so attempt 2 sends the same prompt as attempt 1. Fix needs threading a flag through `StreamProvider` or exposing two closures. Spec'd improvement, not a regression
- `PlanRepository.streamFirstPlan` derives `weekStart` with `Calendar(identifier: .gregorian)` (Sunday-based) while Home/WeekStrip use `.iso8601` (Monday-based). Cosmetic in Plan 3 since the strip is decorative; align before Plan 4 adds session-week comparisons
- `onPersistedWorkout` callbacks read `latestWorkout()` instead of using the `WorkoutPlan` argument — works because `persist` is synchronous on `mainContext`, but fragile. Plan 4 should thread the new `WorkoutEntity.id` through the `.done` event
- Bundled fallback workout deferred to Plan 4 alongside InWorkout

## Module map

- `Packages/CoreModels` — pure value types (Plan, Workout, Feedback, Coach, …)
- `Packages/DesignSystem` — oklch tokens, ThemeStore, primitives
- `Packages/Persistence` — SwiftData @Model entities + ModelContainer factory
- `Packages/Networking` — APIClient, SSEStreamParser, Anthropic request types
- `Packages/Repositories` — UI-facing facade over Persistence + Networking
- `Packages/AppShell` — RootScaffold, PulseTabBar
