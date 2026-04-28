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

## Module map

- `Packages/CoreModels` — pure value types (Plan, Workout, Feedback, Coach, …)
- `Packages/DesignSystem` — oklch tokens, ThemeStore, primitives
- `Packages/Persistence` — SwiftData @Model entities + ModelContainer factory
- `Packages/Networking` — APIClient, SSEStreamParser, Anthropic request types
- `Packages/Repositories` — UI-facing facade over Persistence + Networking
- `Packages/AppShell` — RootScaffold, PulseTabBar
