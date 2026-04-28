# Pulse — Plan 2: App Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the iOS app skeleton with all foundational SPM packages (DesignSystem, CoreModels, Persistence, Networking, Repositories) so that subsequent feature plans can build user-facing flows on top. Output: a buildable empty-shell app with theme provider applied, plus a debug streaming view that proves the live worker pipeline end-to-end.

**Architecture:** Single Xcode project (generated via `xcodegen` from a checked-in `Project.yml`) at `ios/PulseApp.xcodeproj`. Local SPM packages under `ios/Packages/` provide module boundaries. App target wires everything via SwiftUI `@Environment` injection. Secrets (DEVICE_TOKEN, worker URL) baked at build time from `worker/.dev.vars` via a generator script. Watch app target deferred to Plan 4.

**Tech Stack:** Swift 5.9+, SwiftUI, SwiftData, `@Observable` macro, URLSession async/await, xcodegen, XCTest. iOS deployment target: 17.0. Mac host platform also supported in packages so `swift test` runs without a simulator boot.

**Scope outside this plan:** Onboarding/Home/PlanGen/WorkoutDetail features (Plan 3). Watch + HealthKit + InWorkout (Plan 4). Complete + Sentry + TestFlight (Plan 5).

---

## File Structure

After Plan 2 the repo gains:

```
ios/
  Project.yml                          ← xcodegen input (committed)
  PulseApp.xcodeproj/                  ← generated, .gitignored
  PulseApp/                            ← app target sources
    PulseApp.swift                     ← @main entry point
    AppShellRoot.swift                 ← TabView scaffold
    DebugStreamView.swift              ← Plan 2 smoke test UI
    Info.plist
    PulseApp.entitlements
    Assets.xcassets/
      AppIcon.appiconset/
      Contents.json
    Secrets.swift                      ← .gitignored, generated
    Secrets.swift.template             ← committed, shows shape
  Packages/
    CoreModels/                        ← pure value types
    DesignSystem/                      ← tokens, ThemeStore, primitives
    Persistence/                       ← SwiftData stack + @Model entities
    Networking/                        ← APIClient, SSEStreamParser, endpoints
    Repositories/                      ← composes Networking + Persistence
    AppShell/                          ← root scaffold + theme provider
scripts/
  bake-secrets.sh                      ← reads worker/.dev.vars → Secrets.swift
.gitignore                             ← updated to ignore xcodeproj + Secrets.swift
```

---

## Phase A — Project Bootstrap

### Task 1: Verify Xcode + xcodegen + Swift toolchain

**Files:** none (verification only)

- [ ] **Step 1: Verify Xcode is installed and picks the right toolchain**

Run: `xcodebuild -version && xcrun swift --version`
Expected: `Xcode 16.x` (or newer) and `swift-driver version: 1.x ... Apple Swift version 5.9` or newer.

- [ ] **Step 2: Verify or install xcodegen via Homebrew**

Run: `which xcodegen || brew install xcodegen`
Expected: prints a path to `xcodegen` (after install if needed).

- [ ] **Step 3: Verify an iOS 17+ simulator is available**

Run: `xcrun simctl list devices available | grep -E "iPhone 1[5-9]|iPhone 2[0-9]" | head -3`
Expected: at least one iPhone simulator on iOS 17.0 or newer is listed. If none, open Xcode → Settings → Platforms and install the latest iOS simulator runtime.

- [ ] **Step 4: No commit** — verification only.

---

### Task 2: Create `ios/` skeleton directories and update `.gitignore`

**Files:**
- Create: `ios/PulseApp/` (directory)
- Create: `ios/Packages/` (directory)
- Create: `ios/.gitkeep` (placeholder so empty subtree commits)
- Modify: `.gitignore`

- [ ] **Step 1: Create directory skeleton**

Run:
```bash
mkdir -p ios/PulseApp/Assets.xcassets/AppIcon.appiconset
mkdir -p ios/Packages
touch ios/.gitkeep
```

- [ ] **Step 2: Append iOS-specific ignores to `.gitignore`**

Append to `/Users/smwein/Dev Project/Workout App/.gitignore`:

```
# iOS — generated Xcode project + secrets
ios/PulseApp.xcodeproj/
ios/PulseApp.xcworkspace/
ios/PulseApp/Secrets.swift
ios/**/.DS_Store
ios/**/xcuserdata/
ios/**/.swiftpm/
ios/**/.build/
ios/DerivedData/
```

- [ ] **Step 3: Commit**

```bash
git add .gitignore ios/.gitkeep
git commit -m "chore(ios): scaffold ios/ directory skeleton and gitignore"
```

---

### Task 3: Write `Project.yml` for xcodegen (PulseApp target only)

**Files:**
- Create: `ios/Project.yml`

- [ ] **Step 1: Create `ios/Project.yml`**

```yaml
name: PulseApp
options:
  bundleIdPrefix: co.simpleav.pulse
  deploymentTarget:
    iOS: "17.0"
  developmentLanguage: en
  generateEmptyDirectories: true
  createIntermediateGroups: true
settings:
  base:
    SWIFT_VERSION: "5.9"
    ENABLE_USER_SCRIPT_SANDBOXING: NO
    DEVELOPMENT_TEAM: ""
    CODE_SIGN_STYLE: Automatic
    CURRENT_PROJECT_VERSION: 1
    MARKETING_VERSION: "0.2.0"
packages:
  CoreModels:
    path: Packages/CoreModels
  DesignSystem:
    path: Packages/DesignSystem
  Persistence:
    path: Packages/Persistence
  Networking:
    path: Packages/Networking
  Repositories:
    path: Packages/Repositories
  AppShell:
    path: Packages/AppShell
targets:
  PulseApp:
    type: application
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - path: PulseApp
        excludes:
          - "Secrets.swift.template"
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: co.simpleav.pulse
        INFOPLIST_FILE: PulseApp/Info.plist
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
        TARGETED_DEVICE_FAMILY: "1"
        ENABLE_PREVIEWS: YES
        SWIFT_EMIT_LOC_STRINGS: YES
    dependencies:
      - package: CoreModels
      - package: DesignSystem
      - package: Persistence
      - package: Networking
      - package: Repositories
      - package: AppShell
```

- [ ] **Step 2: Commit**

```bash
git add ios/Project.yml
git commit -m "chore(ios): add xcodegen Project.yml for PulseApp target"
```

---

### Task 4: Secrets baking — template, generator script, runtime accessor

**Files:**
- Create: `ios/PulseApp/Secrets.swift.template`
- Create: `scripts/bake-secrets.sh`
- Modify: nothing yet (Secrets.swift is generated, not committed)

- [ ] **Step 1: Create `ios/PulseApp/Secrets.swift.template`**

```swift
// Generated by scripts/bake-secrets.sh — DO NOT EDIT BY HAND.
// Source of truth: worker/.dev.vars
import Foundation

enum Secrets {
    static let workerURL: URL = URL(string: "__WORKER_URL__")!
    static let deviceToken: String = "__DEVICE_TOKEN__"
}
```

- [ ] **Step 2: Create `scripts/bake-secrets.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Generates ios/PulseApp/Secrets.swift from worker/.dev.vars.
# Idempotent — safe to re-run. Run before every Xcode build.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEV_VARS="$REPO_ROOT/worker/.dev.vars"
TEMPLATE="$REPO_ROOT/ios/PulseApp/Secrets.swift.template"
OUTPUT="$REPO_ROOT/ios/PulseApp/Secrets.swift"

if [[ ! -f "$DEV_VARS" ]]; then
  echo "error: $DEV_VARS not found — cannot bake secrets" >&2
  exit 1
fi
if [[ ! -f "$TEMPLATE" ]]; then
  echo "error: $TEMPLATE not found" >&2
  exit 1
fi

# Source the .dev.vars file (KEY=VALUE lines, possibly quoted)
set -a
# shellcheck disable=SC1090
source "$DEV_VARS"
set +a

WORKER_URL="${WORKER_URL:-https://pulse-proxy.smwein.workers.dev/}"
DEVICE_TOKEN="${DEVICE_TOKEN:?DEVICE_TOKEN missing from worker/.dev.vars}"

sed \
  -e "s|__WORKER_URL__|${WORKER_URL}|g" \
  -e "s|__DEVICE_TOKEN__|${DEVICE_TOKEN}|g" \
  "$TEMPLATE" > "$OUTPUT"

echo "baked: $OUTPUT"
```

- [ ] **Step 3: Make the script executable and add `WORKER_URL` to `.dev.vars` if missing**

Run:
```bash
chmod +x scripts/bake-secrets.sh
grep -q '^WORKER_URL=' worker/.dev.vars || echo 'WORKER_URL=https://pulse-proxy.smwein.workers.dev/' >> worker/.dev.vars
```

- [ ] **Step 4: Run the script and confirm output exists**

Run: `./scripts/bake-secrets.sh && test -f ios/PulseApp/Secrets.swift && echo OK`
Expected: prints `baked: .../Secrets.swift` then `OK`. The file should be ignored by git (verify with `git check-ignore -v ios/PulseApp/Secrets.swift`).

- [ ] **Step 5: Commit**

```bash
git add ios/PulseApp/Secrets.swift.template scripts/bake-secrets.sh
git commit -m "chore(ios): add secrets baking script + Secrets.swift.template"
```

---

### Task 5: Minimal app entry point + Info.plist + first xcodegen build

**Files:**
- Create: `ios/PulseApp/PulseApp.swift`
- Create: `ios/PulseApp/Info.plist`
- Create: `ios/PulseApp/PulseApp.entitlements`
- Create: `ios/PulseApp/Assets.xcassets/Contents.json`
- Create: `ios/PulseApp/Assets.xcassets/AppIcon.appiconset/Contents.json`

- [ ] **Step 1: Create the SwiftUI app entry point**

`ios/PulseApp/PulseApp.swift`:
```swift
import SwiftUI

@main
struct PulseApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Pulse — bootstrap")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.ignoresSafeArea())
        }
    }
}
```

- [ ] **Step 2: Create `ios/PulseApp/Info.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>$(DEVELOPMENT_LANGUAGE)</string>
  <key>CFBundleExecutable</key>
  <string>$(EXECUTABLE_NAME)</string>
  <key>CFBundleIdentifier</key>
  <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$(PRODUCT_NAME)</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$(MARKETING_VERSION)</string>
  <key>CFBundleVersion</key>
  <string>$(CURRENT_PROJECT_VERSION)</string>
  <key>LSRequiresIPhoneOS</key>
  <true/>
  <key>UIApplicationSceneManifest</key>
  <dict>
    <key>UIApplicationSupportsMultipleScenes</key>
    <false/>
  </dict>
  <key>UILaunchScreen</key>
  <dict>
    <key>UIColorName</key>
    <string></string>
  </dict>
  <key>UIRequiredDeviceCapabilities</key>
  <array>
    <string>arm64</string>
  </array>
  <key>UISupportedInterfaceOrientations</key>
  <array>
    <string>UIInterfaceOrientationPortrait</string>
  </array>
  <key>UIUserInterfaceStyle</key>
  <string>Dark</string>
</dict>
</plist>
```

- [ ] **Step 3: Create empty entitlements + asset catalog Contents.json files**

`ios/PulseApp/PulseApp.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict/>
</plist>
```

`ios/PulseApp/Assets.xcassets/Contents.json`:
```json
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

`ios/PulseApp/Assets.xcassets/AppIcon.appiconset/Contents.json`:
```json
{
  "images" : [
    {
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

- [ ] **Step 4: Generate the Xcode project — expect failure (packages don't exist yet)**

Run: `cd ios && xcodegen generate`
Expected: xcodegen errors out because `Packages/CoreModels` etc. don't exist. This is OK — confirms xcodegen sees Project.yml.

- [ ] **Step 5: Stub all six packages so xcodegen can resolve them**

Run:
```bash
cd ios
for pkg in CoreModels DesignSystem Persistence Networking Repositories AppShell; do
  mkdir -p "Packages/$pkg/Sources/$pkg"
  cat > "Packages/$pkg/Package.swift" <<EOF
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "$pkg",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "$pkg", targets: ["$pkg"])],
    targets: [.target(name: "$pkg")]
)
EOF
  cat > "Packages/$pkg/Sources/$pkg/${pkg}.swift" <<EOF
// Stubbed by Plan 2 Task 5. Real content lands in subsequent tasks.
public enum ${pkg}Stub {}
EOF
done
```

- [ ] **Step 6: Generate the Xcode project**

Run: `cd ios && xcodegen generate`
Expected: prints `⚙️  Generating project...` and `Created project at /…/ios/PulseApp.xcodeproj`. No errors.

- [ ] **Step 7: Build for iOS Simulator**

Run from repo root:
```bash
xcodebuild -project ios/PulseApp.xcodeproj \
  -scheme PulseApp \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath ios/DerivedData \
  build 2>&1 | tail -20
```
Expected: ends with `** BUILD SUCCEEDED **`.

- [ ] **Step 8: Commit**

```bash
git add ios/PulseApp/PulseApp.swift ios/PulseApp/Info.plist \
        ios/PulseApp/PulseApp.entitlements \
        ios/PulseApp/Assets.xcassets \
        ios/Packages
git commit -m "feat(ios): scaffold PulseApp target + stub packages, first build green"
```

---

## Phase B — CoreModels (pure value types)

These types are the contract between Networking (decoded from LLM JSON), Persistence (encoded to `payloadJSON: Data`), and Features (read-only UI). No iOS frameworks — `swift test` runs on the macOS host.

### Task 6: Replace CoreModels stub with real package layout + first test scaffold

**Files:**
- Modify: `ios/Packages/CoreModels/Package.swift`
- Delete: `ios/Packages/CoreModels/Sources/CoreModels/CoreModels.swift` (the stub)
- Create: `ios/Packages/CoreModels/Tests/CoreModelsTests/SmokeTests.swift`

- [ ] **Step 1: Replace Package.swift with the test-enabled version**

`ios/Packages/CoreModels/Package.swift`:
```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CoreModels",
    platforms: [.iOS(.v17), .macOS(.v14), .watchOS(.v10)],
    products: [.library(name: "CoreModels", targets: ["CoreModels"])],
    targets: [
        .target(name: "CoreModels"),
        .testTarget(name: "CoreModelsTests", dependencies: ["CoreModels"]),
    ]
)
```

- [ ] **Step 2: Remove stub source, create empty marker source so target compiles**

Run:
```bash
rm ios/Packages/CoreModels/Sources/CoreModels/CoreModels.swift
mkdir -p ios/Packages/CoreModels/Tests/CoreModelsTests
```

Create `ios/Packages/CoreModels/Sources/CoreModels/Module.swift`:
```swift
// CoreModels — pure value types for Pulse. See spec section 9.
```

- [ ] **Step 3: Write a smoke test that proves the package builds + tests run**

`ios/Packages/CoreModels/Tests/CoreModelsTests/SmokeTests.swift`:
```swift
import XCTest
@testable import CoreModels

final class SmokeTests: XCTestCase {
    func test_packageImports() {
        XCTAssertTrue(true)
    }
}
```

- [ ] **Step 4: Run the test**

Run: `cd ios/Packages/CoreModels && swift test 2>&1 | tail -10`
Expected: `Test Suite 'All tests' passed` and `Executed 1 test`.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/CoreModels
git commit -m "feat(core-models): initialize package with test scaffold"
```

---

### Task 7: `Coach` value type + accent hue mapping

**Files:**
- Create: `ios/Packages/CoreModels/Sources/CoreModels/Coach.swift`
- Create: `ios/Packages/CoreModels/Tests/CoreModelsTests/CoachTests.swift`

- [ ] **Step 1: Write the failing test**

`ios/Packages/CoreModels/Tests/CoreModelsTests/CoachTests.swift`:
```swift
import XCTest
@testable import CoreModels

final class CoachTests: XCTestCase {
    func test_allCoachesHaveDistinctIDsAndHues() {
        let coaches = Coach.all
        XCTAssertEqual(coaches.count, 4)
        XCTAssertEqual(Set(coaches.map(\.id)).count, 4)
        XCTAssertEqual(Set(coaches.map(\.accentHue)).count, 4)
    }

    func test_lookupByIDReturnsExpectedCoach() {
        XCTAssertEqual(Coach.byID("ace")?.displayName, "Ace")
        XCTAssertEqual(Coach.byID("rex")?.displayName, "Rex")
        XCTAssertEqual(Coach.byID("vera")?.displayName, "Vera")
        XCTAssertEqual(Coach.byID("mira")?.displayName, "Mira")
        XCTAssertNil(Coach.byID("unknown"))
    }

    func test_aceUsesWarmOrangeHue() {
        XCTAssertEqual(Coach.byID("ace")?.accentHue, 45)
    }
}
```

- [ ] **Step 2: Run the test, expect failure**

Run: `cd ios/Packages/CoreModels && swift test 2>&1 | grep -E "error|failed" | head -5`
Expected: errors mentioning `Coach` not found.

- [ ] **Step 3: Implement `Coach`**

`ios/Packages/CoreModels/Sources/CoreModels/Coach.swift`:
```swift
import Foundation

public struct Coach: Identifiable, Hashable, Sendable {
    public let id: String           // "ace" | "rex" | "vera" | "mira"
    public let displayName: String
    public let tagline: String
    public let accentHue: Int       // 0–360, drives DesignSystem accent

    public init(id: String, displayName: String, tagline: String, accentHue: Int) {
        self.id = id
        self.displayName = displayName
        self.tagline = tagline
        self.accentHue = accentHue
    }

    public static let all: [Coach] = [
        Coach(id: "ace",  displayName: "Ace",  tagline: "the friend",   accentHue: 45),
        Coach(id: "rex",  displayName: "Rex",  tagline: "the athlete",  accentHue: 15),
        Coach(id: "vera", displayName: "Vera", tagline: "the analyst",  accentHue: 220),
        Coach(id: "mira", displayName: "Mira", tagline: "the mindful",  accentHue: 285),
    ]

    public static func byID(_ id: String) -> Coach? {
        all.first { $0.id == id }
    }
}
```

- [ ] **Step 4: Run the tests, confirm green**

Run: `cd ios/Packages/CoreModels && swift test 2>&1 | tail -10`
Expected: `Executed 4 tests, with 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/CoreModels/Sources/CoreModels/Coach.swift \
        ios/Packages/CoreModels/Tests/CoreModelsTests/CoachTests.swift
git commit -m "feat(core-models): add Coach with four personalities and accent hues"
```

---

### Task 8: `WorkoutPlan` + `WorkoutBlock` + `Exercise` + `ExerciseSet` Codable contract

**Files:**
- Create: `ios/Packages/CoreModels/Sources/CoreModels/WorkoutPlan.swift`
- Create: `ios/Packages/CoreModels/Tests/CoreModelsTests/WorkoutPlanTests.swift`
- Create: `ios/Packages/CoreModels/Tests/CoreModelsTests/Fixtures/sample-plan.json`

- [ ] **Step 1: Drop a fixture JSON that mirrors what the LLM emits**

Create `ios/Packages/CoreModels/Tests/CoreModelsTests/Fixtures/sample-plan.json`:
```json
{
  "weekStart": "2026-04-27",
  "workouts": [
    {
      "id": "W-2026-04-27",
      "scheduledFor": "2026-04-27T09:00:00Z",
      "title": "Lower Power",
      "subtitle": "Heavy doubles, intent-driven",
      "workoutType": "Strength",
      "durationMin": 48,
      "blocks": [
        {
          "id": "B-warm",
          "label": "Warm-up",
          "exercises": [
            {
              "id": "ex-001",
              "exerciseID": "world_greatest_stretch",
              "name": "World's Greatest Stretch",
              "sets": [
                { "setNum": 1, "reps": 6, "load": "BW", "restSec": 30 }
              ]
            }
          ]
        },
        {
          "id": "B-main",
          "label": "Main",
          "exercises": [
            {
              "id": "ex-002",
              "exerciseID": "back_squat",
              "name": "Back Squat",
              "sets": [
                { "setNum": 1, "reps": 5, "load": "60 kg", "restSec": 120 },
                { "setNum": 2, "reps": 3, "load": "80 kg", "restSec": 180 },
                { "setNum": 3, "reps": 2, "load": "92 kg", "restSec": 180 }
              ]
            }
          ]
        }
      ]
    }
  ]
}
```

- [ ] **Step 2: Update Package.swift to bundle the fixture as a test resource**

In `ios/Packages/CoreModels/Package.swift`, replace the `.testTarget` line so it reads:
```swift
.testTarget(
    name: "CoreModelsTests",
    dependencies: ["CoreModels"],
    resources: [.copy("Fixtures")]
),
```

- [ ] **Step 3: Write the failing test**

`ios/Packages/CoreModels/Tests/CoreModelsTests/WorkoutPlanTests.swift`:
```swift
import XCTest
@testable import CoreModels

final class WorkoutPlanTests: XCTestCase {
    func test_decodesSampleFixture() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "sample-plan", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let plan = try JSONDecoder.pulse.decode(WorkoutPlan.self, from: data)

        XCTAssertEqual(plan.workouts.count, 1)
        let workout = plan.workouts[0]
        XCTAssertEqual(workout.title, "Lower Power")
        XCTAssertEqual(workout.workoutType, "Strength")
        XCTAssertEqual(workout.durationMin, 48)
        XCTAssertEqual(workout.blocks.count, 2)
        XCTAssertEqual(workout.blocks[1].exercises[0].sets.count, 3)
        XCTAssertEqual(workout.blocks[1].exercises[0].sets[2].load, "92 kg")
    }

    func test_roundTripPreservesShape() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "sample-plan", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let original = try JSONDecoder.pulse.decode(WorkoutPlan.self, from: data)
        let encoded = try JSONEncoder.pulse.encode(original)
        let decoded = try JSONDecoder.pulse.decode(WorkoutPlan.self, from: encoded)
        XCTAssertEqual(original, decoded)
    }
}
```

- [ ] **Step 4: Run the test, expect failure**

Run: `cd ios/Packages/CoreModels && swift test 2>&1 | grep -E "error|cannot find" | head -5`
Expected: errors about `WorkoutPlan` not found.

- [ ] **Step 5: Implement `WorkoutPlan` and friends**

`ios/Packages/CoreModels/Sources/CoreModels/WorkoutPlan.swift`:
```swift
import Foundation

public struct WorkoutPlan: Codable, Hashable, Sendable {
    public var weekStart: Date
    public var workouts: [PlannedWorkout]

    public init(weekStart: Date, workouts: [PlannedWorkout]) {
        self.weekStart = weekStart
        self.workouts = workouts
    }
}

public struct PlannedWorkout: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var scheduledFor: Date
    public var title: String
    public var subtitle: String
    public var workoutType: String   // "Strength" | "HIIT" | "Mobility" | ...
    public var durationMin: Int
    public var blocks: [WorkoutBlock]

    public init(id: String, scheduledFor: Date, title: String, subtitle: String,
                workoutType: String, durationMin: Int, blocks: [WorkoutBlock]) {
        self.id = id
        self.scheduledFor = scheduledFor
        self.title = title
        self.subtitle = subtitle
        self.workoutType = workoutType
        self.durationMin = durationMin
        self.blocks = blocks
    }
}

public struct WorkoutBlock: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var label: String          // "Warm-up" | "Main" | "Cooldown"
    public var exercises: [PlannedExercise]

    public init(id: String, label: String, exercises: [PlannedExercise]) {
        self.id = id
        self.label = label
        self.exercises = exercises
    }
}

public struct PlannedExercise: Codable, Hashable, Identifiable, Sendable {
    public var id: String             // unique within plan
    public var exerciseID: String     // matches catalog manifest id
    public var name: String
    public var sets: [PlannedSet]

    public init(id: String, exerciseID: String, name: String, sets: [PlannedSet]) {
        self.id = id
        self.exerciseID = exerciseID
        self.name = name
        self.sets = sets
    }
}

public struct PlannedSet: Codable, Hashable, Sendable {
    public var setNum: Int
    public var reps: Int
    public var load: String           // "BW" | "60 kg" | "0:30"
    public var restSec: Int

    public init(setNum: Int, reps: Int, load: String, restSec: Int) {
        self.setNum = setNum
        self.reps = reps
        self.load = load
        self.restSec = restSec
    }
}

public extension JSONEncoder {
    static let pulse: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }()
}

public extension JSONDecoder {
    static let pulse: JSONDecoder = {
        let d = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        let dateOnly = DateFormatter()
        dateOnly.calendar = Calendar(identifier: .gregorian)
        dateOnly.locale = Locale(identifier: "en_US_POSIX")
        dateOnly.timeZone = TimeZone(secondsFromGMT: 0)
        dateOnly.dateFormat = "yyyy-MM-dd"
        d.dateDecodingStrategy = .custom { decoder in
            let str = try decoder.singleValueContainer().decode(String.self)
            if let date = formatter.date(from: str) { return date }
            if let date = fallback.date(from: str) { return date }
            if let date = dateOnly.date(from: str) { return date }
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Unparseable date: \(str)")
            )
        }
        return d
    }()
}
```

- [ ] **Step 6: Run the tests, confirm green**

Run: `cd ios/Packages/CoreModels && swift test 2>&1 | tail -10`
Expected: `Executed 6 tests, with 0 failures` (smoke + 3 coach + 2 plan).

- [ ] **Step 7: Commit**

```bash
git add ios/Packages/CoreModels
git commit -m "feat(core-models): WorkoutPlan/Block/Exercise/Set with Codable round-trip"
```

---

### Task 9: `WorkoutFeedback` + `SetLogEntry`

**Files:**
- Create: `ios/Packages/CoreModels/Sources/CoreModels/WorkoutFeedback.swift`
- Create: `ios/Packages/CoreModels/Sources/CoreModels/SetLogEntry.swift`
- Create: `ios/Packages/CoreModels/Tests/CoreModelsTests/WorkoutFeedbackTests.swift`

- [ ] **Step 1: Write failing tests**

`ios/Packages/CoreModels/Tests/CoreModelsTests/WorkoutFeedbackTests.swift`:
```swift
import XCTest
@testable import CoreModels

final class WorkoutFeedbackTests: XCTestCase {
    func test_feedbackEncodesAllFields() throws {
        let fb = WorkoutFeedback(
            sessionID: UUID(),
            submittedAt: Date(timeIntervalSince1970: 1_730_000_000),
            rating: 4,
            intensity: 3,
            mood: .good,
            tags: ["energized", "form-good"],
            exerciseRatings: ["ex-002": .up, "ex-001": .down],
            note: "Felt strong on the squats"
        )
        let data = try JSONEncoder.pulse.encode(fb)
        let decoded = try JSONDecoder.pulse.decode(WorkoutFeedback.self, from: data)
        XCTAssertEqual(fb, decoded)
        XCTAssertEqual(decoded.exerciseRatings["ex-002"], .up)
    }

    func test_setLogEntryRoundTrip() throws {
        let entry = SetLogEntry(
            exerciseID: "ex-002",
            setNum: 2,
            reps: 5,
            load: "80 kg",
            rpe: 8,
            loggedAt: Date(timeIntervalSince1970: 1_730_000_500)
        )
        let data = try JSONEncoder.pulse.encode(entry)
        let decoded = try JSONDecoder.pulse.decode(SetLogEntry.self, from: data)
        XCTAssertEqual(entry, decoded)
    }
}
```

- [ ] **Step 2: Run tests, expect failure**

Run: `cd ios/Packages/CoreModels && swift test 2>&1 | grep -E "cannot find" | head -5`
Expected: errors about `WorkoutFeedback` / `SetLogEntry` not found.

- [ ] **Step 3: Implement `WorkoutFeedback`**

`ios/Packages/CoreModels/Sources/CoreModels/WorkoutFeedback.swift`:
```swift
import Foundation

public struct WorkoutFeedback: Codable, Hashable, Sendable {
    public enum Mood: String, Codable, Hashable, Sendable {
        case great, good, ok, rough
    }

    public enum ExerciseRating: String, Codable, Hashable, Sendable {
        case up, down
    }

    public var sessionID: UUID
    public var submittedAt: Date
    public var rating: Int                              // 1...5
    public var intensity: Int                           // 1...5
    public var mood: Mood
    public var tags: [String]
    public var exerciseRatings: [String: ExerciseRating]   // [exerciseID: up|down]
    public var note: String?

    public init(sessionID: UUID, submittedAt: Date, rating: Int, intensity: Int,
                mood: Mood, tags: [String],
                exerciseRatings: [String: ExerciseRating], note: String?) {
        self.sessionID = sessionID
        self.submittedAt = submittedAt
        self.rating = rating
        self.intensity = intensity
        self.mood = mood
        self.tags = tags
        self.exerciseRatings = exerciseRatings
        self.note = note
    }
}
```

- [ ] **Step 4: Implement `SetLogEntry`**

`ios/Packages/CoreModels/Sources/CoreModels/SetLogEntry.swift`:
```swift
import Foundation

/// A logged set, sent over WatchConnectivity from Watch → Phone, then persisted.
public struct SetLogEntry: Codable, Hashable, Sendable {
    public var exerciseID: String
    public var setNum: Int
    public var reps: Int
    public var load: String
    public var rpe: Int          // 1...10
    public var loggedAt: Date

    public init(exerciseID: String, setNum: Int, reps: Int, load: String, rpe: Int, loggedAt: Date) {
        self.exerciseID = exerciseID
        self.setNum = setNum
        self.reps = reps
        self.load = load
        self.rpe = rpe
        self.loggedAt = loggedAt
    }
}
```

- [ ] **Step 5: Run, confirm green**

Run: `cd ios/Packages/CoreModels && swift test 2>&1 | tail -10`
Expected: `Executed 8 tests, with 0 failures`.

- [ ] **Step 6: Commit**

```bash
git add ios/Packages/CoreModels
git commit -m "feat(core-models): WorkoutFeedback (mood/tags/exRatings) + SetLogEntry"
```

---

### Task 10: `AdaptationDiff` + `Profile`

**Files:**
- Create: `ios/Packages/CoreModels/Sources/CoreModels/AdaptationDiff.swift`
- Create: `ios/Packages/CoreModels/Sources/CoreModels/Profile.swift`
- Create: `ios/Packages/CoreModels/Tests/CoreModelsTests/AdaptationDiffTests.swift`
- Create: `ios/Packages/CoreModels/Tests/CoreModelsTests/ProfileTests.swift`

- [ ] **Step 1: Write failing tests**

`ios/Packages/CoreModels/Tests/CoreModelsTests/AdaptationDiffTests.swift`:
```swift
import XCTest
@testable import CoreModels

final class AdaptationDiffTests: XCTestCase {
    func test_diffWithMixedChangesRoundTrips() throws {
        let diff = AdaptationDiff(
            generatedAt: Date(timeIntervalSince1970: 1_730_001_000),
            rationale: "Reduced lower-body volume after rough mood + RPE 9 squats.",
            changes: [
                .swap(from: "back_squat", to: "goblet_squat", reason: "Lighter load, same pattern"),
                .reps(exerciseID: "deadlift", from: 5, to: 3, reason: "Heavier intent"),
                .remove(exerciseID: "burpee", reason: "Recovery day"),
                .add(exerciseID: "pigeon_pose", afterExerciseID: nil, reason: "Hip mobility add-on"),
            ]
        )
        let data = try JSONEncoder.pulse.encode(diff)
        let decoded = try JSONDecoder.pulse.decode(AdaptationDiff.self, from: data)
        XCTAssertEqual(diff, decoded)
        XCTAssertEqual(decoded.changes.count, 4)
    }
}
```

`ios/Packages/CoreModels/Tests/CoreModelsTests/ProfileTests.swift`:
```swift
import XCTest
@testable import CoreModels

final class ProfileTests: XCTestCase {
    func test_profileBuildsFromOnboardingInputs() {
        let p = Profile(
            id: UUID(),
            displayName: "Steven",
            goals: ["build strength", "stay mobile"],
            level: .regular,
            equipment: ["dumbbells", "barbell", "bench"],
            frequencyPerWeek: 4,
            weeklyTargetMinutes: 200,
            activeCoachID: "ace",
            createdAt: Date()
        )
        XCTAssertEqual(p.activeCoachID, "ace")
        XCTAssertEqual(Coach.byID(p.activeCoachID)?.accentHue, 45)
    }
}
```

- [ ] **Step 2: Run, expect failure**

Run: `cd ios/Packages/CoreModels && swift test 2>&1 | grep -E "cannot find" | head -5`
Expected: errors about `AdaptationDiff` and `Profile`.

- [ ] **Step 3: Implement `AdaptationDiff`**

`ios/Packages/CoreModels/Sources/CoreModels/AdaptationDiff.swift`:
```swift
import Foundation

public struct AdaptationDiff: Codable, Hashable, Sendable {
    public var generatedAt: Date
    public var rationale: String
    public var changes: [Change]

    public enum Change: Codable, Hashable, Sendable {
        case swap(from: String, to: String, reason: String)
        case reps(exerciseID: String, from: Int, to: Int, reason: String)
        case load(exerciseID: String, from: String, to: String, reason: String)
        case remove(exerciseID: String, reason: String)
        case add(exerciseID: String, afterExerciseID: String?, reason: String)

        private enum CodingKeys: String, CodingKey {
            case op, from, to, exerciseID, afterExerciseID, reason
        }

        private enum Op: String, Codable { case swap, reps, load, remove, add }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let op = try c.decode(Op.self, forKey: .op)
            let reason = try c.decode(String.self, forKey: .reason)
            switch op {
            case .swap:
                self = .swap(from: try c.decode(String.self, forKey: .from),
                             to: try c.decode(String.self, forKey: .to),
                             reason: reason)
            case .reps:
                self = .reps(exerciseID: try c.decode(String.self, forKey: .exerciseID),
                             from: try c.decode(Int.self, forKey: .from),
                             to: try c.decode(Int.self, forKey: .to),
                             reason: reason)
            case .load:
                self = .load(exerciseID: try c.decode(String.self, forKey: .exerciseID),
                             from: try c.decode(String.self, forKey: .from),
                             to: try c.decode(String.self, forKey: .to),
                             reason: reason)
            case .remove:
                self = .remove(exerciseID: try c.decode(String.self, forKey: .exerciseID),
                               reason: reason)
            case .add:
                self = .add(exerciseID: try c.decode(String.self, forKey: .exerciseID),
                            afterExerciseID: try c.decodeIfPresent(String.self, forKey: .afterExerciseID),
                            reason: reason)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case let .swap(from, to, reason):
                try c.encode(Op.swap, forKey: .op)
                try c.encode(from, forKey: .from)
                try c.encode(to, forKey: .to)
                try c.encode(reason, forKey: .reason)
            case let .reps(exID, from, to, reason):
                try c.encode(Op.reps, forKey: .op)
                try c.encode(exID, forKey: .exerciseID)
                try c.encode(from, forKey: .from)
                try c.encode(to, forKey: .to)
                try c.encode(reason, forKey: .reason)
            case let .load(exID, from, to, reason):
                try c.encode(Op.load, forKey: .op)
                try c.encode(exID, forKey: .exerciseID)
                try c.encode(from, forKey: .from)
                try c.encode(to, forKey: .to)
                try c.encode(reason, forKey: .reason)
            case let .remove(exID, reason):
                try c.encode(Op.remove, forKey: .op)
                try c.encode(exID, forKey: .exerciseID)
                try c.encode(reason, forKey: .reason)
            case let .add(exID, after, reason):
                try c.encode(Op.add, forKey: .op)
                try c.encode(exID, forKey: .exerciseID)
                try c.encodeIfPresent(after, forKey: .afterExerciseID)
                try c.encode(reason, forKey: .reason)
            }
        }
    }

    public init(generatedAt: Date, rationale: String, changes: [Change]) {
        self.generatedAt = generatedAt
        self.rationale = rationale
        self.changes = changes
    }
}
```

- [ ] **Step 4: Implement `Profile`**

`ios/Packages/CoreModels/Sources/CoreModels/Profile.swift`:
```swift
import Foundation

public struct Profile: Codable, Hashable, Sendable, Identifiable {
    public enum Level: String, Codable, Hashable, Sendable {
        case new, regular, experienced, athlete
    }

    public var id: UUID
    public var displayName: String
    public var goals: [String]
    public var level: Level
    public var equipment: [String]
    public var frequencyPerWeek: Int
    public var weeklyTargetMinutes: Int
    public var activeCoachID: String
    public var createdAt: Date

    public init(id: UUID, displayName: String, goals: [String], level: Level,
                equipment: [String], frequencyPerWeek: Int, weeklyTargetMinutes: Int,
                activeCoachID: String, createdAt: Date) {
        self.id = id
        self.displayName = displayName
        self.goals = goals
        self.level = level
        self.equipment = equipment
        self.frequencyPerWeek = frequencyPerWeek
        self.weeklyTargetMinutes = weeklyTargetMinutes
        self.activeCoachID = activeCoachID
        self.createdAt = createdAt
    }
}
```

- [ ] **Step 5: Run, confirm green**

Run: `cd ios/Packages/CoreModels && swift test 2>&1 | tail -10`
Expected: `Executed 10 tests, with 0 failures`.

- [ ] **Step 6: Commit**

```bash
git add ios/Packages/CoreModels
git commit -m "feat(core-models): AdaptationDiff (5 change ops) + Profile value type"
```

---

## Phase C — DesignSystem (tokens, theme, primitives)

### Task 11: Replace DesignSystem stub with real package + test scaffold

**Files:**
- Modify: `ios/Packages/DesignSystem/Package.swift`
- Delete: `ios/Packages/DesignSystem/Sources/DesignSystem/DesignSystem.swift`
- Create: `ios/Packages/DesignSystem/Sources/DesignSystem/Module.swift`
- Create: `ios/Packages/DesignSystem/Tests/DesignSystemTests/SmokeTests.swift`

- [ ] **Step 1: Replace Package.swift**

`ios/Packages/DesignSystem/Package.swift`:
```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DesignSystem",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "DesignSystem", targets: ["DesignSystem"])],
    dependencies: [
        .package(path: "../CoreModels"),
    ],
    targets: [
        .target(name: "DesignSystem", dependencies: ["CoreModels"]),
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem"]),
    ]
)
```

- [ ] **Step 2: Replace stub source**

Run: `rm ios/Packages/DesignSystem/Sources/DesignSystem/DesignSystem.swift`

Create `ios/Packages/DesignSystem/Sources/DesignSystem/Module.swift`:
```swift
// DesignSystem — tokens, ThemeStore, primitives. See spec section 4 + design handoff.
```

- [ ] **Step 3: Add smoke test**

`ios/Packages/DesignSystem/Tests/DesignSystemTests/SmokeTests.swift`:
```swift
import XCTest
@testable import DesignSystem

final class SmokeTests: XCTestCase {
    func test_packageImports() {
        XCTAssertTrue(true)
    }
}
```

- [ ] **Step 4: Run**

Run: `cd ios/Packages/DesignSystem && swift test 2>&1 | tail -10`
Expected: `Executed 1 test, with 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/DesignSystem
git commit -m "feat(design-system): initialize package with CoreModels dep"
```

---

### Task 12: oklch → sRGB color conversion utility

**Files:**
- Create: `ios/Packages/DesignSystem/Sources/DesignSystem/Tokens/Oklch.swift`
- Create: `ios/Packages/DesignSystem/Tests/DesignSystemTests/OklchTests.swift`

- [ ] **Step 1: Write failing tests using known reference values**

Reference values come from running the design CSS through a browser and reading back the computed `rgb()` per token (within ~1 LSB tolerance).

`ios/Packages/DesignSystem/Tests/DesignSystemTests/OklchTests.swift`:
```swift
import XCTest
@testable import DesignSystem

final class OklchTests: XCTestCase {
    func test_pureBlackOklchProducesSrgbZero() {
        let rgb = Oklch(L: 0, C: 0, h: 0).toLinearSrgb().toSrgb()
        XCTAssertEqual(rgb.r, 0, accuracy: 0.005)
        XCTAssertEqual(rgb.g, 0, accuracy: 0.005)
        XCTAssertEqual(rgb.b, 0, accuracy: 0.005)
    }

    func test_pureWhiteOklchProducesSrgbOne() {
        let rgb = Oklch(L: 1, C: 0, h: 0).toLinearSrgb().toSrgb()
        XCTAssertEqual(rgb.r, 1, accuracy: 0.01)
        XCTAssertEqual(rgb.g, 1, accuracy: 0.01)
        XCTAssertEqual(rgb.b, 1, accuracy: 0.01)
    }

    func test_warmAccentOrangeMatchesDesignToken() {
        // --accent: oklch(72% 0.18 45) — warm hot orange
        let rgb = Oklch(L: 0.72, C: 0.18, h: 45).toLinearSrgb().toSrgb()
        // Reference computed via colorjs.io: ~ rgb(243, 158, 88) → (0.953, 0.620, 0.345)
        XCTAssertEqual(rgb.r, 0.953, accuracy: 0.04)
        XCTAssertEqual(rgb.g, 0.620, accuracy: 0.04)
        XCTAssertEqual(rgb.b, 0.345, accuracy: 0.05)
    }

    func test_deepBackgroundOklchIsNearBlack() {
        // --bg-0: oklch(16% 0.005 60)
        let rgb = Oklch(L: 0.16, C: 0.005, h: 60).toLinearSrgb().toSrgb()
        XCTAssertLessThan(rgb.r, 0.10)
        XCTAssertLessThan(rgb.g, 0.10)
        XCTAssertLessThan(rgb.b, 0.10)
        XCTAssertEqual(rgb.r, rgb.g, accuracy: 0.04)  // near-neutral
    }
}
```

- [ ] **Step 2: Run, expect failure**

Run: `cd ios/Packages/DesignSystem && swift test 2>&1 | grep -E "cannot find" | head -5`
Expected: `Oklch` not found.

- [ ] **Step 3: Implement `Oklch` and conversions**

`ios/Packages/DesignSystem/Sources/DesignSystem/Tokens/Oklch.swift`:
```swift
import Foundation

/// oklch (L=0...1, C=0+, h=degrees 0...360) → linear sRGB → sRGB.
/// Formulas per https://bottosson.github.io/posts/oklab/ and CSS Color Module 4.
public struct Oklch: Hashable, Sendable {
    public var L: Double      // 0...1 (CSS uses 0%...100%)
    public var C: Double      // 0...~0.4 typical
    public var h: Double      // degrees 0...360

    public init(L: Double, C: Double, h: Double) {
        self.L = L
        self.C = C
        self.h = h
    }

    public func toLinearSrgb() -> LinearSrgb {
        let hRad = h * .pi / 180
        let a = C * cos(hRad)
        let b = C * sin(hRad)

        let l_ = L + 0.3963377774 * a + 0.2158037573 * b
        let m_ = L - 0.1055613458 * a - 0.0638541728 * b
        let s_ = L - 0.0894841775 * a - 1.2914855480 * b

        let l = l_ * l_ * l_
        let m = m_ * m_ * m_
        let s = s_ * s_ * s_

        let r = +4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
        let g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
        let bb = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
        return LinearSrgb(r: r, g: g, b: bb)
    }
}

public struct LinearSrgb: Hashable, Sendable {
    public var r: Double
    public var g: Double
    public var b: Double

    public init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    public func toSrgb() -> Srgb {
        func encode(_ x: Double) -> Double {
            let clamped = max(0, min(1, x))
            return clamped <= 0.0031308
                ? 12.92 * clamped
                : 1.055 * pow(clamped, 1.0 / 2.4) - 0.055
        }
        return Srgb(r: encode(r), g: encode(g), b: encode(b))
    }
}

public struct Srgb: Hashable, Sendable {
    public var r: Double      // 0...1
    public var g: Double
    public var b: Double

    public init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }
}
```

- [ ] **Step 4: Run, confirm green**

Run: `cd ios/Packages/DesignSystem && swift test 2>&1 | tail -10`
Expected: `Executed 5 tests, with 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/DesignSystem
git commit -m "feat(design-system): oklch → linear sRGB → sRGB conversion + tests"
```

---

### Task 13: Static color tokens — `PulseColors` enum

**Files:**
- Create: `ios/Packages/DesignSystem/Sources/DesignSystem/Tokens/Colors.swift`
- Create: `ios/Packages/DesignSystem/Tests/DesignSystemTests/ColorsTests.swift`

- [ ] **Step 1: Write failing test**

`ios/Packages/DesignSystem/Tests/DesignSystemTests/ColorsTests.swift`:
```swift
import XCTest
import SwiftUI
@testable import DesignSystem

final class ColorsTests: XCTestCase {
    func test_bgScaleProgressivelyLightens() {
        // bg-0 darkest, bg-3 lightest of the dark scale
        let scale = [PulseColors.bg0, PulseColors.bg1, PulseColors.bg2, PulseColors.bg3]
        let lightnesses = scale.map { $0.oklch.L }
        XCTAssertEqual(lightnesses, lightnesses.sorted())
        XCTAssertGreaterThan(scale[3].oklch.L, scale[0].oklch.L)
    }

    func test_inkScaleProgressivelyDarkens() {
        // ink-0 brightest text → ink-3 dimmest
        let scale = [PulseColors.ink0, PulseColors.ink1, PulseColors.ink2, PulseColors.ink3]
        let lightnesses = scale.map { $0.oklch.L }
        XCTAssertEqual(lightnesses, lightnesses.sorted(by: >))
    }

    func test_goodAndWarnAreDistinctHues() {
        XCTAssertNotEqual(PulseColors.good.oklch.h, PulseColors.warn.oklch.h)
    }
}
```

- [ ] **Step 2: Run, expect failure**

Run: `cd ios/Packages/DesignSystem && swift test 2>&1 | grep -E "cannot find" | head -5`

- [ ] **Step 3: Implement static tokens**

`ios/Packages/DesignSystem/Sources/DesignSystem/Tokens/Colors.swift`:
```swift
import SwiftUI

/// A token color: holds the source oklch + a derived SwiftUI Color computed once.
public struct PulseColor: Hashable, Sendable {
    public let oklch: Oklch
    public let opacity: Double

    public init(_ oklch: Oklch, opacity: Double = 1) {
        self.oklch = oklch
        self.opacity = opacity
    }

    public var color: Color {
        let srgb = oklch.toLinearSrgb().toSrgb()
        return Color(.sRGB, red: srgb.r, green: srgb.g, blue: srgb.b, opacity: opacity)
    }
}

public enum PulseColors {
    // Backgrounds (dark → less dark)
    public static let bg0 = PulseColor(Oklch(L: 0.16, C: 0.005, h: 60))
    public static let bg1 = PulseColor(Oklch(L: 0.20, C: 0.006, h: 60))
    public static let bg2 = PulseColor(Oklch(L: 0.24, C: 0.008, h: 60))
    public static let bg3 = PulseColor(Oklch(L: 0.30, C: 0.010, h: 60))

    // Lines / dividers
    public static let line = PulseColor(Oklch(L: 0.32, C: 0.008, h: 60), opacity: 0.6)
    public static let lineSoft = PulseColor(Oklch(L: 0.40, C: 0.008, h: 60), opacity: 0.25)

    // Ink (text, brightest → dimmest)
    public static let ink0 = PulseColor(Oklch(L: 0.97, C: 0.005, h: 80))
    public static let ink1 = PulseColor(Oklch(L: 0.82, C: 0.008, h: 80))
    public static let ink2 = PulseColor(Oklch(L: 0.64, C: 0.010, h: 80))
    public static let ink3 = PulseColor(Oklch(L: 0.46, C: 0.012, h: 80))

    // Functional
    public static let good = PulseColor(Oklch(L: 0.78, C: 0.14, h: 150))
    public static let warn = PulseColor(Oklch(L: 0.78, C: 0.14, h: 80))
}
```

- [ ] **Step 4: Run, confirm green**

Run: `cd ios/Packages/DesignSystem && swift test 2>&1 | tail -10`
Expected: `Executed 8 tests, with 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/DesignSystem
git commit -m "feat(design-system): static color tokens (bg/ink/line/good/warn)"
```

---

### Task 14: Accent generator — `AccentPalette(hue:)` derives 4 accent colors

**Files:**
- Create: `ios/Packages/DesignSystem/Sources/DesignSystem/Tokens/AccentPalette.swift`
- Create: `ios/Packages/DesignSystem/Tests/DesignSystemTests/AccentPaletteTests.swift`

- [ ] **Step 1: Write failing tests**

`ios/Packages/DesignSystem/Tests/DesignSystemTests/AccentPaletteTests.swift`:
```swift
import XCTest
@testable import DesignSystem

final class AccentPaletteTests: XCTestCase {
    func test_paletteHasFourTones() {
        let p = AccentPalette(hue: 45)
        XCTAssertEqual(p.base.oklch.h, 45)
        XCTAssertEqual(p.soft.oklch.h, 45)
        XCTAssertEqual(p.ink.oklch.h, 45)
        XCTAssertEqual(p.glow.oklch.h, 45)
    }

    func test_softVariantIsTransparent() {
        XCTAssertLessThan(AccentPalette(hue: 45).soft.opacity, 0.5)
    }

    func test_inkVariantIsDark() {
        // accent-ink for primary button text on accent background — must be dark
        XCTAssertLessThan(AccentPalette(hue: 45).ink.oklch.L, 0.30)
    }

    func test_differentHuesProduceDifferentColors() {
        let warm = AccentPalette(hue: 45)
        let cool = AccentPalette(hue: 220)
        XCTAssertNotEqual(warm.base.oklch.h, cool.base.oklch.h)
    }
}
```

- [ ] **Step 2: Run, expect failure**

Run: `cd ios/Packages/DesignSystem && swift test 2>&1 | grep -E "cannot find" | head -5`

- [ ] **Step 3: Implement `AccentPalette`**

`ios/Packages/DesignSystem/Sources/DesignSystem/Tokens/AccentPalette.swift`:
```swift
import Foundation

/// Derives the 4 accent tones from a single hue (0...360).
/// Mirrors the design CSS:
///   --accent:      oklch(72% 0.18 var(--accent-h))
///   --accent-soft: oklch(72% 0.18 var(--accent-h) / 0.18)
///   --accent-ink:  oklch(20% 0.05 var(--accent-h))
///   --glow:        oklch(72% 0.18 var(--accent-h) / 0.5)  (used in box-shadow)
public struct AccentPalette: Hashable, Sendable {
    public let hue: Double
    public let base: PulseColor
    public let soft: PulseColor
    public let ink: PulseColor
    public let glow: PulseColor

    public init(hue: Int) {
        self.init(hue: Double(hue))
    }

    public init(hue: Double) {
        self.hue = hue
        self.base = PulseColor(Oklch(L: 0.72, C: 0.18, h: hue))
        self.soft = PulseColor(Oklch(L: 0.72, C: 0.18, h: hue), opacity: 0.18)
        self.ink  = PulseColor(Oklch(L: 0.20, C: 0.05, h: hue))
        self.glow = PulseColor(Oklch(L: 0.72, C: 0.18, h: hue), opacity: 0.5)
    }
}
```

- [ ] **Step 4: Run, confirm green**

Run: `cd ios/Packages/DesignSystem && swift test 2>&1 | tail -10`
Expected: `Executed 12 tests, with 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/DesignSystem
git commit -m "feat(design-system): AccentPalette derives 4 tones from a single hue"
```

---

### Task 15: Typography tokens — `PulseFont`

**Files:**
- Create: `ios/Packages/DesignSystem/Sources/DesignSystem/Tokens/Typography.swift`
- Create: `ios/Packages/DesignSystem/Tests/DesignSystemTests/TypographyTests.swift`

- [ ] **Step 1: Write failing test**

`ios/Packages/DesignSystem/Tests/DesignSystemTests/TypographyTests.swift`:
```swift
import XCTest
@testable import DesignSystem

final class TypographyTests: XCTestCase {
    func test_typeScaleSizesMatchDesign() {
        XCTAssertEqual(PulseFont.eyebrow.size, 11)
        XCTAssertEqual(PulseFont.h1.size, 28)
        XCTAssertEqual(PulseFont.h2.size, 22)
        XCTAssertEqual(PulseFont.h3.size, 17)
        XCTAssertEqual(PulseFont.body.size, 15)
        XCTAssertEqual(PulseFont.small.size, 13)
    }

    func test_displayUsesSerifFamily() {
        XCTAssertEqual(PulseFont.display.family, .display)
    }

    func test_eyebrowAndMonoUseMonoFamily() {
        XCTAssertEqual(PulseFont.eyebrow.family, .mono)
        XCTAssertEqual(PulseFont.mono.family, .mono)
    }
}
```

- [ ] **Step 2: Run, expect failure**

Run: `cd ios/Packages/DesignSystem && swift test 2>&1 | grep -E "cannot find" | head -5`

- [ ] **Step 3: Implement `PulseFont`**

`ios/Packages/DesignSystem/Sources/DesignSystem/Tokens/Typography.swift`:
```swift
import SwiftUI

public enum PulseFontFamily: Hashable, Sendable {
    case display    // Instrument Serif (italic display)
    case sans       // Inter Tight / system fallback
    case mono       // JetBrains Mono / SF Mono fallback

    /// Maps to a SwiftUI font family. We use system fonts as fallbacks; custom font
    /// registration is out of scope for Plan 2 — bundled font assets land in Plan 3.
    public var systemFallback: Font.Design {
        switch self {
        case .display: return .serif
        case .sans:    return .default
        case .mono:    return .monospaced
        }
    }
}

public struct PulseFont: Hashable, Sendable {
    public let family: PulseFontFamily
    public let size: CGFloat
    public let weight: Font.Weight
    public let italic: Bool
    public let lineHeightMultiple: CGFloat
    public let trackingEm: Double

    public init(family: PulseFontFamily, size: CGFloat, weight: Font.Weight,
                italic: Bool = false, lineHeightMultiple: CGFloat = 1.2, trackingEm: Double = 0) {
        self.family = family
        self.size = size
        self.weight = weight
        self.italic = italic
        self.lineHeightMultiple = lineHeightMultiple
        self.trackingEm = trackingEm
    }

    public var swiftUIFont: Font {
        var f = Font.system(size: size, weight: weight, design: family.systemFallback)
        if italic { f = f.italic() }
        return f
    }
}

public extension PulseFont {
    static let eyebrow = PulseFont(family: .mono, size: 11, weight: .regular,
                                   lineHeightMultiple: 1.0, trackingEm: 0.14)
    static let display = PulseFont(family: .display, size: 36, weight: .regular,
                                   italic: true, lineHeightMultiple: 0.95, trackingEm: -0.02)
    static let h1 = PulseFont(family: .sans, size: 28, weight: .semibold,
                              lineHeightMultiple: 1.1, trackingEm: -0.02)
    static let h2 = PulseFont(family: .sans, size: 22, weight: .semibold,
                              lineHeightMultiple: 1.15, trackingEm: -0.02)
    static let h3 = PulseFont(family: .sans, size: 17, weight: .semibold,
                              lineHeightMultiple: 1.2, trackingEm: -0.01)
    static let body = PulseFont(family: .sans, size: 15, weight: .regular,
                                lineHeightMultiple: 1.45)
    static let small = PulseFont(family: .sans, size: 13, weight: .regular,
                                 lineHeightMultiple: 1.4)
    static let mono = PulseFont(family: .mono, size: 13, weight: .regular,
                                lineHeightMultiple: 1.4)
}

public extension View {
    func pulseFont(_ token: PulseFont) -> some View {
        self.font(token.swiftUIFont)
            .tracking(CGFloat(token.trackingEm) * token.size)
    }
}
```

- [ ] **Step 4: Run, confirm green**

Run: `cd ios/Packages/DesignSystem && swift test 2>&1 | tail -10`
Expected: `Executed 15 tests, with 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/DesignSystem
git commit -m "feat(design-system): typography tokens + .pulseFont() modifier"
```

---

### Task 16: Radius + Spacing + Motion tokens

**Files:**
- Create: `ios/Packages/DesignSystem/Sources/DesignSystem/Tokens/Radius.swift`
- Create: `ios/Packages/DesignSystem/Sources/DesignSystem/Tokens/Spacing.swift`
- Create: `ios/Packages/DesignSystem/Sources/DesignSystem/Tokens/Motion.swift`
- Create: `ios/Packages/DesignSystem/Tests/DesignSystemTests/MetricsTests.swift`

- [ ] **Step 1: Write failing test**

`ios/Packages/DesignSystem/Tests/DesignSystemTests/MetricsTests.swift`:
```swift
import XCTest
@testable import DesignSystem

final class MetricsTests: XCTestCase {
    func test_radiiMatchDesignTokens() {
        XCTAssertEqual(PulseRadius.sm, 10)
        XCTAssertEqual(PulseRadius.md, 16)
        XCTAssertEqual(PulseRadius.lg, 22)
        XCTAssertEqual(PulseRadius.xl, 28)
    }

    func test_spacingFollows4ptGrid() {
        XCTAssertEqual(PulseSpacing.xxs, 2)
        XCTAssertEqual(PulseSpacing.xs, 4)
        XCTAssertEqual(PulseSpacing.sm, 8)
        XCTAssertEqual(PulseSpacing.md, 12)
        XCTAssertEqual(PulseSpacing.lg, 16)
        XCTAssertEqual(PulseSpacing.xl, 24)
        XCTAssertEqual(PulseSpacing.xxl, 32)
    }

    func test_motionDurationsAreNonZero() {
        XCTAssertGreaterThan(PulseMotion.fast, 0)
        XCTAssertGreaterThan(PulseMotion.standard, PulseMotion.fast)
        XCTAssertGreaterThan(PulseMotion.slow, PulseMotion.standard)
    }
}
```

- [ ] **Step 2: Run, expect failure**

Run: `cd ios/Packages/DesignSystem && swift test 2>&1 | grep -E "cannot find" | head -5`

- [ ] **Step 3: Implement tokens**

`ios/Packages/DesignSystem/Sources/DesignSystem/Tokens/Radius.swift`:
```swift
import CoreGraphics

public enum PulseRadius {
    public static let sm: CGFloat = 10
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 22
    public static let xl: CGFloat = 28
}
```

`ios/Packages/DesignSystem/Sources/DesignSystem/Tokens/Spacing.swift`:
```swift
import CoreGraphics

public enum PulseSpacing {
    public static let xxs: CGFloat = 2
    public static let xs:  CGFloat = 4
    public static let sm:  CGFloat = 8
    public static let md:  CGFloat = 12
    public static let lg:  CGFloat = 16
    public static let xl:  CGFloat = 24
    public static let xxl: CGFloat = 32
}
```

`ios/Packages/DesignSystem/Sources/DesignSystem/Tokens/Motion.swift`:
```swift
import SwiftUI

public enum PulseMotion {
    public static let fast: Double = 0.18
    public static let standard: Double = 0.32
    public static let slow: Double = 0.6

    public static let easeOut = Animation.timingCurve(0.22, 1, 0.36, 1, duration: standard)
    public static let easeIn  = Animation.timingCurve(0.64, 0, 0.78, 0, duration: standard)
    public static let easeSoft = Animation.timingCurve(0.4, 0, 0.2, 1, duration: standard)
}
```

- [ ] **Step 4: Run, confirm green**

Run: `cd ios/Packages/DesignSystem && swift test 2>&1 | tail -10`
Expected: `Executed 18 tests, with 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/DesignSystem
git commit -m "feat(design-system): radius + spacing + motion tokens"
```

---

### Task 17: `ThemeStore` (@Observable) + `Theme` SwiftUI environment

**Files:**
- Create: `ios/Packages/DesignSystem/Sources/DesignSystem/Theme/ThemeStore.swift`
- Create: `ios/Packages/DesignSystem/Sources/DesignSystem/Theme/ThemeEnvironment.swift`
- Create: `ios/Packages/DesignSystem/Tests/DesignSystemTests/ThemeStoreTests.swift`

- [ ] **Step 1: Write failing test**

`ios/Packages/DesignSystem/Tests/DesignSystemTests/ThemeStoreTests.swift`:
```swift
import XCTest
import CoreModels
@testable import DesignSystem

final class ThemeStoreTests: XCTestCase {
    func test_defaultsToAceWarmOrange() {
        let store = ThemeStore()
        XCTAssertEqual(store.activeCoachID, "ace")
        XCTAssertEqual(store.accent.hue, 45)
    }

    func test_settingActiveCoachUpdatesAccentImmediately() {
        let store = ThemeStore()
        store.setActiveCoach(id: "vera")
        XCTAssertEqual(store.activeCoachID, "vera")
        XCTAssertEqual(store.accent.hue, 220)
    }

    func test_unknownCoachIDIsIgnored() {
        let store = ThemeStore()
        store.setActiveCoach(id: "nope")
        XCTAssertEqual(store.activeCoachID, "ace")
    }
}
```

- [ ] **Step 2: Run, expect failure**

Run: `cd ios/Packages/DesignSystem && swift test 2>&1 | grep -E "cannot find" | head -5`

- [ ] **Step 3: Implement `ThemeStore`**

`ios/Packages/DesignSystem/Sources/DesignSystem/Theme/ThemeStore.swift`:
```swift
import Foundation
import Observation
import CoreModels

@Observable
public final class ThemeStore {
    public private(set) var activeCoachID: String
    public private(set) var accent: AccentPalette

    public init(activeCoachID: String = "ace") {
        let resolved = Coach.byID(activeCoachID) ?? Coach.byID("ace")!
        self.activeCoachID = resolved.id
        self.accent = AccentPalette(hue: resolved.accentHue)
    }

    public func setActiveCoach(id: String) {
        guard let coach = Coach.byID(id) else { return }
        self.activeCoachID = coach.id
        self.accent = AccentPalette(hue: coach.accentHue)
    }
}
```

- [ ] **Step 4: Implement environment value + view modifier**

`ios/Packages/DesignSystem/Sources/DesignSystem/Theme/ThemeEnvironment.swift`:
```swift
import SwiftUI

private struct ThemeStoreKey: EnvironmentKey {
    static let defaultValue: ThemeStore = ThemeStore()
}

public extension EnvironmentValues {
    var pulseTheme: ThemeStore {
        get { self[ThemeStoreKey.self] }
        set { self[ThemeStoreKey.self] = newValue }
    }
}

public extension View {
    func pulseTheme(_ store: ThemeStore) -> some View {
        self.environment(\.pulseTheme, store)
    }
}
```

- [ ] **Step 5: Run, confirm green**

Run: `cd ios/Packages/DesignSystem && swift test 2>&1 | tail -10`
Expected: `Executed 21 tests, with 0 failures`.

- [ ] **Step 6: Commit**

```bash
git add ios/Packages/DesignSystem
git commit -m "feat(design-system): ThemeStore (@Observable) + pulseTheme env value"
```

---

### Task 18: `PulseCard` primitive

**Files:**
- Create: `ios/Packages/DesignSystem/Sources/DesignSystem/Primitives/PulseCard.swift`
- Create: `ios/Packages/DesignSystem/Tests/DesignSystemTests/PulseCardTests.swift`

- [ ] **Step 1: Write failing test (renders without crashing, exposes content)**

`ios/Packages/DesignSystem/Tests/DesignSystemTests/PulseCardTests.swift`:
```swift
import XCTest
import SwiftUI
@testable import DesignSystem

final class PulseCardTests: XCTestCase {
    func test_cardWrapsArbitraryContent() {
        let card = PulseCard { Text("hello") }
        // Initialization must not crash; ViewBuilder closure must compile against any View.
        _ = card.body
    }
}
```

- [ ] **Step 2: Run, expect failure**

Run: `cd ios/Packages/DesignSystem && swift test 2>&1 | grep -E "cannot find" | head -3`

- [ ] **Step 3: Implement `PulseCard`**

`ios/Packages/DesignSystem/Sources/DesignSystem/Primitives/PulseCard.swift`:
```swift
import SwiftUI

public struct PulseCard<Content: View>: View {
    private let content: Content
    private let padding: CGFloat
    private let cornerRadius: CGFloat

    public init(padding: CGFloat = PulseSpacing.lg,
                cornerRadius: CGFloat = PulseRadius.lg,
                @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(PulseColors.bg1.color)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(PulseColors.line.color, lineWidth: 1)
            )
    }
}
```

- [ ] **Step 4: Run, confirm green**

Run: `cd ios/Packages/DesignSystem && swift test 2>&1 | tail -10`
Expected: `Executed 22 tests, with 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/DesignSystem
git commit -m "feat(design-system): PulseCard primitive (bg1 + 1px line + 22pt radius)"
```

---

### Task 19: `PulseButton` primitive (primary, ghost, lg variants)

**Files:**
- Create: `ios/Packages/DesignSystem/Sources/DesignSystem/Primitives/PulseButton.swift`
- Create: `ios/Packages/DesignSystem/Tests/DesignSystemTests/PulseButtonTests.swift`

- [ ] **Step 1: Write failing test**

`ios/Packages/DesignSystem/Tests/DesignSystemTests/PulseButtonTests.swift`:
```swift
import XCTest
import SwiftUI
@testable import DesignSystem

final class PulseButtonTests: XCTestCase {
    func test_buttonRendersAllVariantsWithoutCrash() {
        for variant in [PulseButton.Variant.primary, .ghost] {
            for size in [PulseButton.Size.regular, .large] {
                let button = PulseButton("Start", variant: variant, size: size, action: {})
                _ = button.body
            }
        }
    }

    func test_buttonInvokesActionClosureType() {
        var fired = false
        let button = PulseButton("Tap", action: { fired = true })
        _ = button.body
        // Direct closure invocation as a sanity check on capture
        button.action()
        XCTAssertTrue(fired)
    }
}
```

- [ ] **Step 2: Run, expect failure**

Run: `cd ios/Packages/DesignSystem && swift test 2>&1 | grep -E "cannot find" | head -3`

- [ ] **Step 3: Implement `PulseButton`**

`ios/Packages/DesignSystem/Sources/DesignSystem/Primitives/PulseButton.swift`:
```swift
import SwiftUI

public struct PulseButton: View {
    public enum Variant { case primary, ghost }
    public enum Size { case regular, large }

    public let title: String
    public let variant: Variant
    public let size: Size
    public let action: () -> Void

    @Environment(\.pulseTheme) private var theme

    public init(_ title: String, variant: Variant = .primary, size: Size = .regular,
                action: @escaping () -> Void) {
        self.title = title
        self.variant = variant
        self.size = size
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .pulseFont(size == .large ? PulseFont.h3 : PulseFont.body)
                .padding(.horizontal, size == .large ? 26 : 18)
                .padding(.vertical, size == .large ? 18 : 12)
                .frame(minWidth: 0)
                .foregroundStyle(foreground)
                .background(background)
                .overlay(border)
                .clipShape(RoundedRectangle(cornerRadius: PulseRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var foreground: Color {
        switch variant {
        case .primary: return theme.accent.ink.color
        case .ghost:   return PulseColors.ink0.color
        }
    }

    private var background: some View {
        Group {
            switch variant {
            case .primary: theme.accent.base.color
            case .ghost:   PulseColors.bg1.color
            }
        }
    }

    @ViewBuilder
    private var border: some View {
        if variant == .ghost {
            RoundedRectangle(cornerRadius: PulseRadius.md, style: .continuous)
                .strokeBorder(PulseColors.line.color, lineWidth: 1)
        }
    }
}
```

- [ ] **Step 4: Run, confirm green**

Run: `cd ios/Packages/DesignSystem && swift test 2>&1 | tail -10`
Expected: `Executed 24 tests, with 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/DesignSystem
git commit -m "feat(design-system): PulseButton (primary/ghost × regular/large)"
```

---

### Task 20: `PulsePill` primitive (default + accent variants)

**Files:**
- Create: `ios/Packages/DesignSystem/Sources/DesignSystem/Primitives/PulsePill.swift`
- Create: `ios/Packages/DesignSystem/Tests/DesignSystemTests/PulsePillTests.swift`

- [ ] **Step 1: Write failing test**

`ios/Packages/DesignSystem/Tests/DesignSystemTests/PulsePillTests.swift`:
```swift
import XCTest
import SwiftUI
@testable import DesignSystem

final class PulsePillTests: XCTestCase {
    func test_pillRendersBothVariants() {
        _ = PulsePill("48 min").body
        _ = PulsePill("Strength", variant: .accent).body
    }
}
```

- [ ] **Step 2: Run, expect failure**

Run: `cd ios/Packages/DesignSystem && swift test 2>&1 | grep -E "cannot find" | head -3`

- [ ] **Step 3: Implement `PulsePill`**

`ios/Packages/DesignSystem/Sources/DesignSystem/Primitives/PulsePill.swift`:
```swift
import SwiftUI

public struct PulsePill: View {
    public enum Variant { case `default`, accent }

    public let text: String
    public let variant: Variant

    @Environment(\.pulseTheme) private var theme

    public init(_ text: String, variant: Variant = .default) {
        self.text = text
        self.variant = variant
    }

    public var body: some View {
        Text(text)
            .pulseFont(.mono)
            .foregroundStyle(foreground)
            .padding(.horizontal, PulseSpacing.md)
            .padding(.vertical, PulseSpacing.xs + 2)
            .background(
                Capsule(style: .continuous).fill(background)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(PulseColors.line.color, lineWidth: variant == .accent ? 0 : 1)
            )
    }

    private var foreground: Color {
        switch variant {
        case .default: return PulseColors.ink1.color
        case .accent:  return theme.accent.base.color
        }
    }

    private var background: Color {
        switch variant {
        case .default: return PulseColors.bg2.color
        case .accent:  return theme.accent.soft.color
        }
    }
}
```

- [ ] **Step 4: Run, confirm green**

Run: `cd ios/Packages/DesignSystem && swift test 2>&1 | tail -10`
Expected: `Executed 25 tests, with 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/DesignSystem
git commit -m "feat(design-system): PulsePill (default + accent)"
```

---

### Task 21: `IconButton` primitive (SF Symbol)

**Files:**
- Create: `ios/Packages/DesignSystem/Sources/DesignSystem/Primitives/IconButton.swift`
- Create: `ios/Packages/DesignSystem/Tests/DesignSystemTests/IconButtonTests.swift`

- [ ] **Step 1: Write failing test**

`ios/Packages/DesignSystem/Tests/DesignSystemTests/IconButtonTests.swift`:
```swift
import XCTest
import SwiftUI
@testable import DesignSystem

final class IconButtonTests: XCTestCase {
    func test_iconButtonRenders() {
        _ = IconButton(systemName: "gear", action: {}).body
    }
}
```

- [ ] **Step 2: Run, expect failure**

Run: `cd ios/Packages/DesignSystem && swift test 2>&1 | grep -E "cannot find" | head -3`

- [ ] **Step 3: Implement `IconButton`**

`ios/Packages/DesignSystem/Sources/DesignSystem/Primitives/IconButton.swift`:
```swift
import SwiftUI

public struct IconButton: View {
    public let systemName: String
    public let action: () -> Void

    public init(systemName: String, action: @escaping () -> Void) {
        self.systemName = systemName
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(PulseColors.ink1.color)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: PulseRadius.sm, style: .continuous)
                        .fill(PulseColors.bg1.color)
                )
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 4: Run, confirm green**

Run: `cd ios/Packages/DesignSystem && swift test 2>&1 | tail -10`
Expected: `Executed 26 tests, with 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/DesignSystem
git commit -m "feat(design-system): IconButton primitive (SF Symbol, 36×36, bg1)"
```

---

### Task 22: `TopBar` primitive (eyebrow + title + trailing slot)

**Files:**
- Create: `ios/Packages/DesignSystem/Sources/DesignSystem/Primitives/TopBar.swift`
- Create: `ios/Packages/DesignSystem/Tests/DesignSystemTests/TopBarTests.swift`

- [ ] **Step 1: Write failing test**

`ios/Packages/DesignSystem/Tests/DesignSystemTests/TopBarTests.swift`:
```swift
import XCTest
import SwiftUI
@testable import DesignSystem

final class TopBarTests: XCTestCase {
    func test_topBarRendersWithAndWithoutTrailing() {
        _ = TopBar(eyebrow: "TODAY", title: "Lower Power").body
        _ = TopBar(eyebrow: "TODAY", title: "Lower Power") {
            IconButton(systemName: "gear", action: {})
        }.body
    }
}
```

- [ ] **Step 2: Run, expect failure**

Run: `cd ios/Packages/DesignSystem && swift test 2>&1 | grep -E "cannot find" | head -3`

- [ ] **Step 3: Implement `TopBar`**

`ios/Packages/DesignSystem/Sources/DesignSystem/Primitives/TopBar.swift`:
```swift
import SwiftUI

public struct TopBar<Trailing: View>: View {
    public let eyebrow: String?
    public let title: String
    private let trailing: Trailing

    public init(eyebrow: String? = nil, title: String,
                @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.eyebrow = eyebrow
        self.title = title
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(alignment: .center, spacing: PulseSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                if let eyebrow {
                    Text(eyebrow.uppercased())
                        .pulseFont(.eyebrow)
                        .foregroundStyle(PulseColors.ink2.color)
                }
                Text(title)
                    .pulseFont(.h2)
                    .foregroundStyle(PulseColors.ink0.color)
            }
            Spacer(minLength: 0)
            trailing
        }
        .padding(.horizontal, PulseSpacing.lg)
        .padding(.vertical, PulseSpacing.md)
    }
}
```

- [ ] **Step 4: Run, confirm green**

Run: `cd ios/Packages/DesignSystem && swift test 2>&1 | tail -10`
Expected: `Executed 27 tests, with 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/DesignSystem
git commit -m "feat(design-system): TopBar primitive (eyebrow + title + trailing slot)"
```

---

### Task 23: `Ring` primitive (progress arc)

**Files:**
- Create: `ios/Packages/DesignSystem/Sources/DesignSystem/Primitives/Ring.swift`
- Create: `ios/Packages/DesignSystem/Tests/DesignSystemTests/RingTests.swift`

- [ ] **Step 1: Write failing test**

`ios/Packages/DesignSystem/Tests/DesignSystemTests/RingTests.swift`:
```swift
import XCTest
import SwiftUI
@testable import DesignSystem

final class RingTests: XCTestCase {
    func test_ringClampsProgressToZeroOne() {
        XCTAssertEqual(Ring(progress: -0.5).clampedProgress, 0)
        XCTAssertEqual(Ring(progress: 1.7).clampedProgress, 1)
        XCTAssertEqual(Ring(progress: 0.42).clampedProgress, 0.42, accuracy: 0.0001)
    }

    func test_ringRenders() {
        _ = Ring(progress: 0.65, size: 120, lineWidth: 10).body
    }
}
```

- [ ] **Step 2: Run, expect failure**

Run: `cd ios/Packages/DesignSystem && swift test 2>&1 | grep -E "cannot find" | head -3`

- [ ] **Step 3: Implement `Ring`**

`ios/Packages/DesignSystem/Sources/DesignSystem/Primitives/Ring.swift`:
```swift
import SwiftUI

public struct Ring: View {
    public let progress: Double
    public let size: CGFloat
    public let lineWidth: CGFloat

    @Environment(\.pulseTheme) private var theme

    public init(progress: Double, size: CGFloat = 120, lineWidth: CGFloat = 10) {
        self.progress = progress
        self.size = size
        self.lineWidth = lineWidth
    }

    public var clampedProgress: Double {
        max(0, min(1, progress))
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(PulseColors.bg2.color, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(theme.accent.base.color,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(PulseMotion.easeOut, value: clampedProgress)
        }
        .frame(width: size, height: size)
    }
}
```

- [ ] **Step 4: Run, confirm green**

Run: `cd ios/Packages/DesignSystem && swift test 2>&1 | tail -10`
Expected: `Executed 29 tests, with 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/DesignSystem
git commit -m "feat(design-system): Ring progress primitive (clamped, animated, accent-tinted)"
```

---

### Task 24: `CoachAvatar` primitive

**Files:**
- Create: `ios/Packages/DesignSystem/Sources/DesignSystem/Primitives/CoachAvatar.swift`
- Create: `ios/Packages/DesignSystem/Tests/DesignSystemTests/CoachAvatarTests.swift`

- [ ] **Step 1: Write failing test**

`ios/Packages/DesignSystem/Tests/DesignSystemTests/CoachAvatarTests.swift`:
```swift
import XCTest
import SwiftUI
import CoreModels
@testable import DesignSystem

final class CoachAvatarTests: XCTestCase {
    func test_avatarRendersForEachCoach() {
        for coach in Coach.all {
            _ = CoachAvatar(coach: coach, size: 56).body
        }
    }
}
```

- [ ] **Step 2: Run, expect failure**

Run: `cd ios/Packages/DesignSystem && swift test 2>&1 | grep -E "cannot find" | head -3`

- [ ] **Step 3: Implement `CoachAvatar`**

`ios/Packages/DesignSystem/Sources/DesignSystem/Primitives/CoachAvatar.swift`:
```swift
import SwiftUI
import CoreModels

public struct CoachAvatar: View {
    public let coach: Coach
    public let size: CGFloat

    public init(coach: Coach, size: CGFloat = 56) {
        self.coach = coach
        self.size = size
    }

    private var palette: AccentPalette { AccentPalette(hue: coach.accentHue) }

    private var initial: String {
        coach.displayName.prefix(1).uppercased()
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [palette.base.color, palette.ink.color],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            Text(initial)
                .pulseFont(PulseFont(family: .display, size: size * 0.5,
                                     weight: .regular, italic: true))
                .foregroundStyle(palette.ink.color)
        }
        .frame(width: size, height: size)
        .overlay(
            Circle().strokeBorder(PulseColors.lineSoft.color, lineWidth: 1)
        )
    }
}
```

- [ ] **Step 4: Run, confirm green**

Run: `cd ios/Packages/DesignSystem && swift test 2>&1 | tail -10`
Expected: `Executed 30 tests, with 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/DesignSystem
git commit -m "feat(design-system): CoachAvatar (gradient circle + display initial)"
```

---

### Task 25: `ExercisePlaceholder` primitive (cinematic loop placeholder)

**Files:**
- Create: `ios/Packages/DesignSystem/Sources/DesignSystem/Primitives/ExercisePlaceholder.swift`
- Create: `ios/Packages/DesignSystem/Tests/DesignSystemTests/ExercisePlaceholderTests.swift`

- [ ] **Step 1: Write failing test**

`ios/Packages/DesignSystem/Tests/DesignSystemTests/ExercisePlaceholderTests.swift`:
```swift
import XCTest
import SwiftUI
@testable import DesignSystem

final class ExercisePlaceholderTests: XCTestCase {
    func test_placeholderRenders() {
        _ = ExercisePlaceholder(label: "BACK SQUAT").body
    }
}
```

- [ ] **Step 2: Run, expect failure**

Run: `cd ios/Packages/DesignSystem && swift test 2>&1 | grep -E "cannot find" | head -3`

- [ ] **Step 3: Implement `ExercisePlaceholder`**

`ios/Packages/DesignSystem/Sources/DesignSystem/Primitives/ExercisePlaceholder.swift`:
```swift
import SwiftUI

/// Stand-in for the cinematic exercise demo loop. Real video lands when AVPlayer
/// integration ships in Plan 3 (PlanGeneration → Workout Detail).
public struct ExercisePlaceholder: View {
    public let label: String

    @Environment(\.pulseTheme) private var theme

    public init(label: String) {
        self.label = label
    }

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    theme.accent.base.color.opacity(0.35),
                    PulseColors.bg2.color,
                    PulseColors.bg0.color,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [theme.accent.base.color.opacity(0.18), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 280
            )
            VStack {
                Spacer()
                HStack {
                    Text(label.uppercased())
                        .pulseFont(.eyebrow)
                        .foregroundStyle(PulseColors.ink2.color)
                    Spacer()
                }
            }
            .padding(PulseSpacing.lg)
        }
        .clipShape(RoundedRectangle(cornerRadius: PulseRadius.lg, style: .continuous))
    }
}
```

- [ ] **Step 4: Run, confirm green**

Run: `cd ios/Packages/DesignSystem && swift test 2>&1 | tail -10`
Expected: `Executed 31 tests, with 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/DesignSystem
git commit -m "feat(design-system): ExercisePlaceholder (cinematic gradient + label)"
```

---

## Phase D — Persistence (SwiftData entities)

### Task 26: Replace Persistence stub + ModelContainer factory

**Files:**
- Modify: `ios/Packages/Persistence/Package.swift`
- Delete: `ios/Packages/Persistence/Sources/Persistence/Persistence.swift`
- Create: `ios/Packages/Persistence/Sources/Persistence/PulseModelContainer.swift`
- Create: `ios/Packages/Persistence/Tests/PersistenceTests/ModelContainerTests.swift`

- [ ] **Step 1: Replace Package.swift**

`ios/Packages/Persistence/Package.swift`:
```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Persistence",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "Persistence", targets: ["Persistence"])],
    dependencies: [
        .package(path: "../CoreModels"),
    ],
    targets: [
        .target(name: "Persistence", dependencies: ["CoreModels"]),
        .testTarget(name: "PersistenceTests", dependencies: ["Persistence"]),
    ]
)
```

- [ ] **Step 2: Drop the stub source**

Run: `rm ios/Packages/Persistence/Sources/Persistence/Persistence.swift`

- [ ] **Step 3: Write failing test for in-memory container**

`ios/Packages/Persistence/Tests/PersistenceTests/ModelContainerTests.swift`:
```swift
import XCTest
import SwiftData
@testable import Persistence

final class ModelContainerTests: XCTestCase {
    func test_inMemoryContainerInstantiates() throws {
        let container = try PulseModelContainer.inMemory()
        XCTAssertNotNil(container)
        XCTAssertNotNil(container.mainContext)
    }
}
```

- [ ] **Step 4: Run, expect failure**

Run: `cd ios/Packages/Persistence && swift test 2>&1 | grep -E "cannot find|error:" | head -5`

- [ ] **Step 5: Implement the factory (model array empty initially — populated as entities land)**

`ios/Packages/Persistence/Sources/Persistence/PulseModelContainer.swift`:
```swift
import Foundation
import SwiftData

public enum PulseModelContainer {
    /// Aggregates every @Model used by the app. Entities are appended here as they're added.
    public static var schema: Schema {
        Schema([
            ProfileEntity.self,
            PlanEntity.self,
            WorkoutEntity.self,
            SessionEntity.self,
            SetLogEntity.self,
            FeedbackEntity.self,
            AdaptationEntity.self,
            ExerciseAssetEntity.self,
        ])
    }

    public static func inMemory() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    public static func onDisk(url: URL) throws -> ModelContainer {
        let config = ModelConfiguration(url: url)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
```

> Note: this references entity types created in tasks 27–30. Don't run tests until after Task 30 — the build will fail otherwise. **Skip Step 6 until Task 30.**

- [ ] **Step 6: Commit (skip the local test run; it will pass after Task 30)**

```bash
git add ios/Packages/Persistence
git commit -m "feat(persistence): initialize package + ModelContainer factory (entities pending)"
```

---

### Task 27: `ProfileEntity` + `PlanEntity`

**Files:**
- Create: `ios/Packages/Persistence/Sources/Persistence/Entities/ProfileEntity.swift`
- Create: `ios/Packages/Persistence/Sources/Persistence/Entities/PlanEntity.swift`
- Create: `ios/Packages/Persistence/Tests/PersistenceTests/ProfileEntityTests.swift`
- Create: `ios/Packages/Persistence/Tests/PersistenceTests/PlanEntityTests.swift`

- [ ] **Step 1: Implement `ProfileEntity`**

`ios/Packages/Persistence/Sources/Persistence/Entities/ProfileEntity.swift`:
```swift
import Foundation
import SwiftData

@Model
public final class ProfileEntity {
    @Attribute(.unique) public var id: UUID
    public var userID: UUID?
    public var displayName: String
    public var goals: [String]
    public var level: String
    public var equipment: [String]
    public var frequencyPerWeek: Int
    public var weeklyTargetMinutes: Int
    public var activeCoachID: String
    public var accentHue: Int
    public var createdAt: Date

    public init(id: UUID, userID: UUID? = nil, displayName: String, goals: [String],
                level: String, equipment: [String], frequencyPerWeek: Int,
                weeklyTargetMinutes: Int, activeCoachID: String, accentHue: Int,
                createdAt: Date) {
        self.id = id
        self.userID = userID
        self.displayName = displayName
        self.goals = goals
        self.level = level
        self.equipment = equipment
        self.frequencyPerWeek = frequencyPerWeek
        self.weeklyTargetMinutes = weeklyTargetMinutes
        self.activeCoachID = activeCoachID
        self.accentHue = accentHue
        self.createdAt = createdAt
    }
}
```

- [ ] **Step 2: Implement `PlanEntity`**

`ios/Packages/Persistence/Sources/Persistence/Entities/PlanEntity.swift`:
```swift
import Foundation
import SwiftData

@Model
public final class PlanEntity {
    @Attribute(.unique) public var id: UUID
    public var userID: UUID?
    public var weekStart: Date
    public var generatedAt: Date
    public var modelUsed: String
    public var promptTokens: Int
    public var completionTokens: Int
    @Attribute(.externalStorage) public var payloadJSON: Data

    public init(id: UUID, userID: UUID? = nil, weekStart: Date, generatedAt: Date,
                modelUsed: String, promptTokens: Int, completionTokens: Int,
                payloadJSON: Data) {
        self.id = id
        self.userID = userID
        self.weekStart = weekStart
        self.generatedAt = generatedAt
        self.modelUsed = modelUsed
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.payloadJSON = payloadJSON
    }
}
```

- [ ] **Step 3: Write tests**

`ios/Packages/Persistence/Tests/PersistenceTests/ProfileEntityTests.swift`:
```swift
import XCTest
import SwiftData
@testable import Persistence

final class ProfileEntityTests: XCTestCase {
    func test_persistAndFetchProfile() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let p = ProfileEntity(id: UUID(), displayName: "Steven",
                              goals: ["strength"], level: "regular",
                              equipment: ["barbell"], frequencyPerWeek: 4,
                              weeklyTargetMinutes: 200, activeCoachID: "ace",
                              accentHue: 45, createdAt: Date())
        ctx.insert(p)
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<ProfileEntity>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.displayName, "Steven")
    }
}
```

`ios/Packages/Persistence/Tests/PersistenceTests/PlanEntityTests.swift`:
```swift
import XCTest
import SwiftData
@testable import Persistence

final class PlanEntityTests: XCTestCase {
    func test_persistAndFetchPlanWithExternalStorage() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let payload = #"{"weekStart":"2026-04-27","workouts":[]}"#.data(using: .utf8)!
        let plan = PlanEntity(id: UUID(),
                              weekStart: Date(),
                              generatedAt: Date(),
                              modelUsed: "claude-opus-4-7",
                              promptTokens: 1200,
                              completionTokens: 800,
                              payloadJSON: payload)
        ctx.insert(plan)
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<PlanEntity>())
        XCTAssertEqual(fetched.first?.payloadJSON, payload)
    }
}
```

- [ ] **Step 4: Tests still won't pass until Task 30 lands (other entities not yet defined)**

Skip running. Commit and move on.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/Persistence
git commit -m "feat(persistence): ProfileEntity + PlanEntity (@Model)"
```

---

### Task 28: `WorkoutEntity` + `SessionEntity`

**Files:**
- Create: `ios/Packages/Persistence/Sources/Persistence/Entities/WorkoutEntity.swift`
- Create: `ios/Packages/Persistence/Sources/Persistence/Entities/SessionEntity.swift`
- Create: `ios/Packages/Persistence/Tests/PersistenceTests/WorkoutEntityTests.swift`

- [ ] **Step 1: Implement `WorkoutEntity`**

`ios/Packages/Persistence/Sources/Persistence/Entities/WorkoutEntity.swift`:
```swift
import Foundation
import SwiftData

@Model
public final class WorkoutEntity {
    @Attribute(.unique) public var id: UUID
    public var userID: UUID?
    public var planID: UUID
    public var scheduledFor: Date
    public var title: String
    public var subtitle: String
    public var workoutType: String
    public var durationMin: Int
    public var status: String       // "scheduled" | "in_progress" | "completed" | "skipped"
    @Attribute(.externalStorage) public var blocksJSON: Data
    @Attribute(.externalStorage) public var exercisesJSON: Data
    @Attribute(.externalStorage) public var whispersJSON: Data?

    public init(id: UUID, userID: UUID? = nil, planID: UUID, scheduledFor: Date,
                title: String, subtitle: String, workoutType: String, durationMin: Int,
                status: String, blocksJSON: Data, exercisesJSON: Data,
                whispersJSON: Data? = nil) {
        self.id = id
        self.userID = userID
        self.planID = planID
        self.scheduledFor = scheduledFor
        self.title = title
        self.subtitle = subtitle
        self.workoutType = workoutType
        self.durationMin = durationMin
        self.status = status
        self.blocksJSON = blocksJSON
        self.exercisesJSON = exercisesJSON
        self.whispersJSON = whispersJSON
    }
}
```

- [ ] **Step 2: Implement `SessionEntity`**

`ios/Packages/Persistence/Sources/Persistence/Entities/SessionEntity.swift`:
```swift
import Foundation
import SwiftData

@Model
public final class SessionEntity {
    @Attribute(.unique) public var id: UUID
    public var userID: UUID?
    public var workoutID: UUID
    public var startedAt: Date
    public var completedAt: Date?
    public var avgHR: Int?
    public var kcal: Int?
    public var durationSec: Int?
    public var watchSessionUUID: UUID?
    @Relationship(deleteRule: .cascade, inverse: \SetLogEntity.session)
    public var setLogs: [SetLogEntity] = []
    @Relationship(deleteRule: .cascade, inverse: \FeedbackEntity.session)
    public var feedback: FeedbackEntity?

    public init(id: UUID, userID: UUID? = nil, workoutID: UUID, startedAt: Date,
                completedAt: Date? = nil, avgHR: Int? = nil, kcal: Int? = nil,
                durationSec: Int? = nil, watchSessionUUID: UUID? = nil) {
        self.id = id
        self.userID = userID
        self.workoutID = workoutID
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.avgHR = avgHR
        self.kcal = kcal
        self.durationSec = durationSec
        self.watchSessionUUID = watchSessionUUID
    }
}
```

- [ ] **Step 3: Write WorkoutEntity round-trip test**

`ios/Packages/Persistence/Tests/PersistenceTests/WorkoutEntityTests.swift`:
```swift
import XCTest
import SwiftData
@testable import Persistence

final class WorkoutEntityTests: XCTestCase {
    func test_persistAndFetchWorkout() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let w = WorkoutEntity(
            id: UUID(),
            planID: UUID(),
            scheduledFor: Date(),
            title: "Lower Power",
            subtitle: "Heavy doubles",
            workoutType: "Strength",
            durationMin: 48,
            status: "scheduled",
            blocksJSON: Data("[]".utf8),
            exercisesJSON: Data("[]".utf8)
        )
        ctx.insert(w)
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<WorkoutEntity>())
        XCTAssertEqual(fetched.first?.title, "Lower Power")
        XCTAssertEqual(fetched.first?.status, "scheduled")
    }
}
```

- [ ] **Step 4: Tests still gated until Task 30. Skip running.**

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/Persistence
git commit -m "feat(persistence): WorkoutEntity + SessionEntity with cascade relationships"
```

---

### Task 29: `SetLogEntity` + `FeedbackEntity` + `AdaptationEntity`

**Files:**
- Create: `ios/Packages/Persistence/Sources/Persistence/Entities/SetLogEntity.swift`
- Create: `ios/Packages/Persistence/Sources/Persistence/Entities/FeedbackEntity.swift`
- Create: `ios/Packages/Persistence/Sources/Persistence/Entities/AdaptationEntity.swift`
- Create: `ios/Packages/Persistence/Tests/PersistenceTests/SetLogEntityTests.swift`

- [ ] **Step 1: Implement `SetLogEntity`**

`ios/Packages/Persistence/Sources/Persistence/Entities/SetLogEntity.swift`:
```swift
import Foundation
import SwiftData

@Model
public final class SetLogEntity {
    public var sessionID: UUID
    public var exerciseID: String
    public var setNum: Int
    public var reps: Int
    public var load: String
    public var rpe: Int
    public var loggedAt: Date
    public var session: SessionEntity?

    public init(sessionID: UUID, exerciseID: String, setNum: Int, reps: Int,
                load: String, rpe: Int, loggedAt: Date, session: SessionEntity? = nil) {
        self.sessionID = sessionID
        self.exerciseID = exerciseID
        self.setNum = setNum
        self.reps = reps
        self.load = load
        self.rpe = rpe
        self.loggedAt = loggedAt
        self.session = session
    }
}
```

- [ ] **Step 2: Implement `FeedbackEntity`**

`ios/Packages/Persistence/Sources/Persistence/Entities/FeedbackEntity.swift`:
```swift
import Foundation
import SwiftData

@Model
public final class FeedbackEntity {
    @Attribute(.unique) public var id: UUID
    public var userID: UUID?
    public var session: SessionEntity?
    public var submittedAt: Date
    public var rating: Int
    public var intensity: Int
    public var mood: String
    public var tags: [String]
    @Attribute(.externalStorage) public var exRatingsJSON: Data
    public var note: String?

    public init(id: UUID, userID: UUID? = nil, session: SessionEntity? = nil,
                submittedAt: Date, rating: Int, intensity: Int, mood: String,
                tags: [String], exRatingsJSON: Data, note: String? = nil) {
        self.id = id
        self.userID = userID
        self.session = session
        self.submittedAt = submittedAt
        self.rating = rating
        self.intensity = intensity
        self.mood = mood
        self.tags = tags
        self.exRatingsJSON = exRatingsJSON
        self.note = note
    }
}
```

- [ ] **Step 3: Implement `AdaptationEntity`**

`ios/Packages/Persistence/Sources/Persistence/Entities/AdaptationEntity.swift`:
```swift
import Foundation
import SwiftData

@Model
public final class AdaptationEntity {
    @Attribute(.unique) public var id: UUID
    public var userID: UUID?
    public var feedbackID: UUID
    public var appliedToPlanID: UUID
    public var generatedAt: Date
    public var modelUsed: String
    public var promptTokens: Int
    public var completionTokens: Int
    @Attribute(.externalStorage) public var diffJSON: Data
    public var rationale: String

    public init(id: UUID, userID: UUID? = nil, feedbackID: UUID, appliedToPlanID: UUID,
                generatedAt: Date, modelUsed: String, promptTokens: Int,
                completionTokens: Int, diffJSON: Data, rationale: String) {
        self.id = id
        self.userID = userID
        self.feedbackID = feedbackID
        self.appliedToPlanID = appliedToPlanID
        self.generatedAt = generatedAt
        self.modelUsed = modelUsed
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.diffJSON = diffJSON
        self.rationale = rationale
    }
}
```

- [ ] **Step 4: Write SetLog round-trip test**

`ios/Packages/Persistence/Tests/PersistenceTests/SetLogEntityTests.swift`:
```swift
import XCTest
import SwiftData
@testable import Persistence

final class SetLogEntityTests: XCTestCase {
    func test_setLogPersistsAttachedToSession() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let session = SessionEntity(id: UUID(), workoutID: UUID(), startedAt: Date())
        ctx.insert(session)
        let log = SetLogEntity(sessionID: session.id, exerciseID: "back_squat",
                               setNum: 1, reps: 5, load: "60 kg", rpe: 7,
                               loggedAt: Date(), session: session)
        ctx.insert(log)
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<SessionEntity>())
        XCTAssertEqual(fetched.first?.setLogs.count, 1)
        XCTAssertEqual(fetched.first?.setLogs.first?.exerciseID, "back_squat")
    }
}
```

- [ ] **Step 5: Tests still gated. Skip running.**

- [ ] **Step 6: Commit**

```bash
git add ios/Packages/Persistence
git commit -m "feat(persistence): SetLog + Feedback + Adaptation entities"
```

---

### Task 30: `ExerciseAssetEntity` + run all Persistence tests green

**Files:**
- Create: `ios/Packages/Persistence/Sources/Persistence/Entities/ExerciseAssetEntity.swift`
- Create: `ios/Packages/Persistence/Tests/PersistenceTests/ExerciseAssetEntityTests.swift`

- [ ] **Step 1: Implement `ExerciseAssetEntity`**

`ios/Packages/Persistence/Sources/Persistence/Entities/ExerciseAssetEntity.swift`:
```swift
import Foundation
import SwiftData

@Model
public final class ExerciseAssetEntity {
    @Attribute(.unique) public var id: String   // matches catalog manifest ID
    public var name: String
    public var focus: String
    public var level: String
    public var kind: String
    public var equipment: [String]
    public var videoURL: URL
    public var posterURL: URL
    @Attribute(.externalStorage) public var instructionsJSON: Data
    public var manifestVersion: Int

    public init(id: String, name: String, focus: String, level: String, kind: String,
                equipment: [String], videoURL: URL, posterURL: URL,
                instructionsJSON: Data, manifestVersion: Int) {
        self.id = id
        self.name = name
        self.focus = focus
        self.level = level
        self.kind = kind
        self.equipment = equipment
        self.videoURL = videoURL
        self.posterURL = posterURL
        self.instructionsJSON = instructionsJSON
        self.manifestVersion = manifestVersion
    }
}
```

- [ ] **Step 2: Write ExerciseAsset test**

`ios/Packages/Persistence/Tests/PersistenceTests/ExerciseAssetEntityTests.swift`:
```swift
import XCTest
import SwiftData
@testable import Persistence

final class ExerciseAssetEntityTests: XCTestCase {
    func test_exerciseAssetPersistsAndDedupesByID() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let asset = ExerciseAssetEntity(
            id: "back_squat",
            name: "Back Squat",
            focus: "legs",
            level: "intermediate",
            kind: "strength",
            equipment: ["barbell"],
            videoURL: URL(string: "https://pub-x.r2.dev/exercises/back_squat.mp4")!,
            posterURL: URL(string: "https://pub-x.r2.dev/exercises/back_squat-poster.jpg")!,
            instructionsJSON: Data("[]".utf8),
            manifestVersion: 1
        )
        ctx.insert(asset)
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<ExerciseAssetEntity>(
            predicate: #Predicate { $0.id == "back_squat" }
        ))
        XCTAssertEqual(fetched.count, 1)
    }
}
```

- [ ] **Step 3: Run the full Persistence test suite**

Run: `cd ios/Packages/Persistence && swift test 2>&1 | tail -10`
Expected: `Executed 6 tests, with 0 failures` (1 container + 1 profile + 1 plan + 1 workout + 1 setlog + 1 asset).

- [ ] **Step 4: Commit**

```bash
git add ios/Packages/Persistence
git commit -m "feat(persistence): ExerciseAssetEntity — Persistence test suite green"
```

---

## Phase E — Networking (APIClient, SSE, endpoints)

### Task 31: Replace Networking stub + smoke test

**Files:**
- Modify: `ios/Packages/Networking/Package.swift`
- Delete: `ios/Packages/Networking/Sources/Networking/Networking.swift`
- Create: `ios/Packages/Networking/Sources/Networking/Module.swift`
- Create: `ios/Packages/Networking/Tests/NetworkingTests/SmokeTests.swift`

- [ ] **Step 1: Replace Package.swift**

`ios/Packages/Networking/Package.swift`:
```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Networking",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "Networking", targets: ["Networking"])],
    dependencies: [
        .package(path: "../CoreModels"),
    ],
    targets: [
        .target(name: "Networking", dependencies: ["CoreModels"]),
        .testTarget(
            name: "NetworkingTests",
            dependencies: ["Networking"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
```

- [ ] **Step 2: Replace stub source**

Run:
```bash
rm ios/Packages/Networking/Sources/Networking/Networking.swift
mkdir -p ios/Packages/Networking/Tests/NetworkingTests/Fixtures
```

Create `ios/Packages/Networking/Sources/Networking/Module.swift`:
```swift
// Networking — APIClient, SSEStreamParser, Anthropic endpoints. Spec sections 6 + 7.
```

- [ ] **Step 3: Smoke test**

`ios/Packages/Networking/Tests/NetworkingTests/SmokeTests.swift`:
```swift
import XCTest
@testable import Networking

final class SmokeTests: XCTestCase {
    func test_packageImports() {
        XCTAssertTrue(true)
    }
}
```

- [ ] **Step 4: Run**

Run: `cd ios/Packages/Networking && swift test 2>&1 | tail -10`
Expected: `Executed 1 test, with 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/Networking
git commit -m "feat(networking): initialize package with CoreModels dep + Fixtures dir"
```

---

### Task 32: `SSEStreamParser` + recorded fixture tests

**Files:**
- Create: `ios/Packages/Networking/Sources/Networking/SSE/SSEStreamParser.swift`
- Create: `ios/Packages/Networking/Sources/Networking/SSE/SSEEvent.swift`
- Create: `ios/Packages/Networking/Tests/NetworkingTests/Fixtures/sample-stream.txt`
- Create: `ios/Packages/Networking/Tests/NetworkingTests/SSEStreamParserTests.swift`

- [ ] **Step 1: Drop a recorded SSE fixture**

`ios/Packages/Networking/Tests/NetworkingTests/Fixtures/sample-stream.txt` (literal — note CRLFs are NOT required, the parser uses `\n\n` boundaries):
```
event: message_start
data: {"type":"message_start","message":{"id":"msg_1","model":"claude-opus-4-7"}}

event: content_block_delta
data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"Hello "}}

event: content_block_delta
data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"world"}}

event: message_stop
data: {"type":"message_stop"}

```

- [ ] **Step 2: Write failing tests**

`ios/Packages/Networking/Tests/NetworkingTests/SSEStreamParserTests.swift`:
```swift
import XCTest
@testable import Networking

final class SSEStreamParserTests: XCTestCase {
    func test_parsesCompleteEventsFromSingleChunk() throws {
        var parser = SSEStreamParser()
        let url = try XCTUnwrap(Bundle.module.url(forResource: "sample-stream", withExtension: "txt"))
        let data = try Data(contentsOf: url)
        let events = parser.feed(data)
        XCTAssertEqual(events.count, 4)
        XCTAssertEqual(events[0].event, "message_start")
        XCTAssertEqual(events[1].event, "content_block_delta")
        XCTAssertTrue(events[1].data.contains("Hello"))
    }

    func test_buffersIncompleteEventAcrossChunks() {
        var parser = SSEStreamParser()
        let first = "event: foo\ndata: {\"x\":1".data(using: .utf8)!
        XCTAssertTrue(parser.feed(first).isEmpty)
        let second = "}\n\nevent: bar\ndata: {}\n\n".data(using: .utf8)!
        let events = parser.feed(second)
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].event, "foo")
        XCTAssertEqual(events[0].data, "{\"x\":1}")
        XCTAssertEqual(events[1].event, "bar")
    }

    func test_handlesEventsWithoutExplicitEventName() {
        var parser = SSEStreamParser()
        let chunk = "data: {\"only\":\"data\"}\n\n".data(using: .utf8)!
        let events = parser.feed(chunk)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].event, "message")  // default per SSE spec
    }
}
```

- [ ] **Step 3: Run, expect failure**

Run: `cd ios/Packages/Networking && swift test 2>&1 | grep -E "cannot find" | head -3`

- [ ] **Step 4: Implement `SSEEvent` + `SSEStreamParser`**

`ios/Packages/Networking/Sources/Networking/SSE/SSEEvent.swift`:
```swift
import Foundation

public struct SSEEvent: Hashable, Sendable {
    public let event: String
    public let data: String
    public let id: String?

    public init(event: String, data: String, id: String? = nil) {
        self.event = event
        self.data = data
        self.id = id
    }
}
```

`ios/Packages/Networking/Sources/Networking/SSE/SSEStreamParser.swift`:
```swift
import Foundation

/// Incremental SSE parser. Feed `Data` chunks as they arrive; receive complete
/// events back. Buffers partial events across chunk boundaries.
public struct SSEStreamParser {
    private var buffer = ""

    public init() {}

    public mutating func feed(_ chunk: Data) -> [SSEEvent] {
        guard let s = String(data: chunk, encoding: .utf8) else { return [] }
        buffer.append(s)

        var events: [SSEEvent] = []
        // Events are separated by a blank line ("\n\n" or "\r\n\r\n").
        while let range = buffer.range(of: "\n\n") {
            let raw = String(buffer[..<range.lowerBound])
            buffer.removeSubrange(buffer.startIndex..<range.upperBound)
            if let evt = Self.parseEvent(raw) {
                events.append(evt)
            }
        }
        return events
    }

    private static func parseEvent(_ raw: String) -> SSEEvent? {
        var event = "message"
        var dataLines: [String] = []
        var id: String? = nil
        for line in raw.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix(":") { continue }            // comment
            guard let colon = line.firstIndex(of: ":") else { continue }
            let field = String(line[..<colon])
            var value = String(line[line.index(after: colon)...])
            if value.hasPrefix(" ") { value.removeFirst() }
            switch field {
            case "event": event = value
            case "data":  dataLines.append(value)
            case "id":    id = value
            default: break
            }
        }
        guard !dataLines.isEmpty else { return nil }
        return SSEEvent(event: event, data: dataLines.joined(separator: "\n"), id: id)
    }
}
```

- [ ] **Step 5: Run, confirm green**

Run: `cd ios/Packages/Networking && swift test 2>&1 | tail -10`
Expected: `Executed 4 tests, with 0 failures`.

- [ ] **Step 6: Commit**

```bash
git add ios/Packages/Networking
git commit -m "feat(networking): SSEStreamParser with chunk-boundary buffering"
```

---

### Task 33: `CheckpointExtractor` (parses `⟦CHECKPOINT: ...⟧` markers from text deltas)

**Files:**
- Create: `ios/Packages/Networking/Sources/Networking/SSE/CheckpointExtractor.swift`
- Create: `ios/Packages/Networking/Tests/NetworkingTests/CheckpointExtractorTests.swift`

- [ ] **Step 1: Write failing tests**

`ios/Packages/Networking/Tests/NetworkingTests/CheckpointExtractorTests.swift`:
```swift
import XCTest
@testable import Networking

final class CheckpointExtractorTests: XCTestCase {
    func test_extractsSingleCheckpoint() {
        var ex = CheckpointExtractor()
        let result = ex.feed("Considering recovery ⟦CHECKPOINT: scanning recent sessions⟧ now picking moves")
        XCTAssertEqual(result.checkpoints, ["scanning recent sessions"])
        XCTAssertEqual(result.passthroughText, "Considering recovery  now picking moves")
    }

    func test_buffersAcrossChunksWhenCheckpointSplits() {
        var ex = CheckpointExtractor()
        let r1 = ex.feed("intro ⟦CHECKPOINT: half")
        XCTAssertTrue(r1.checkpoints.isEmpty)
        XCTAssertEqual(r1.passthroughText, "intro ")
        let r2 = ex.feed(" of marker⟧ tail")
        XCTAssertEqual(r2.checkpoints, ["half of marker"])
        XCTAssertEqual(r2.passthroughText, " tail")
    }

    func test_extractsMultipleCheckpointsInOrder() {
        var ex = CheckpointExtractor()
        let r = ex.feed("a⟦CHECKPOINT: one⟧b⟦CHECKPOINT: two⟧c")
        XCTAssertEqual(r.checkpoints, ["one", "two"])
        XCTAssertEqual(r.passthroughText, "abc")
    }
}
```

- [ ] **Step 2: Run, expect failure**

Run: `cd ios/Packages/Networking && swift test 2>&1 | grep -E "cannot find" | head -3`

- [ ] **Step 3: Implement `CheckpointExtractor`**

`ios/Packages/Networking/Sources/Networking/SSE/CheckpointExtractor.swift`:
```swift
import Foundation

public struct CheckpointExtractor {
    public struct Result: Equatable {
        public let passthroughText: String
        public let checkpoints: [String]
    }

    private static let openMarker = "⟦CHECKPOINT: "
    private static let closeMarker = "⟧"

    private var buffer = ""

    public init() {}

    public mutating func feed(_ chunk: String) -> Result {
        buffer.append(chunk)

        var passthrough = ""
        var checkpoints: [String] = []

        while let openRange = buffer.range(of: Self.openMarker) {
            // Emit text before the open marker
            passthrough.append(contentsOf: buffer[..<openRange.lowerBound])
            // Look for matching close marker after the open
            let afterOpen = openRange.upperBound
            if let closeRange = buffer.range(of: Self.closeMarker, range: afterOpen..<buffer.endIndex) {
                let label = String(buffer[afterOpen..<closeRange.lowerBound])
                checkpoints.append(label)
                buffer.removeSubrange(buffer.startIndex..<closeRange.upperBound)
            } else {
                // Open marker without close — keep everything from openRange onward in buffer
                buffer.removeSubrange(buffer.startIndex..<openRange.lowerBound)
                return Result(passthroughText: passthrough, checkpoints: checkpoints)
            }
        }
        // No more open markers; buffer might still hold a partial open prefix
        // (e.g. ending with "⟦CHECK"). Don't emit those bytes yet.
        if let partial = Self.partialOpenSuffixIndex(in: buffer) {
            passthrough.append(contentsOf: buffer[..<partial])
            buffer.removeSubrange(buffer.startIndex..<partial)
        } else {
            passthrough.append(buffer)
            buffer.removeAll(keepingCapacity: true)
        }
        return Result(passthroughText: passthrough, checkpoints: checkpoints)
    }

    /// If the buffer ends with a strict prefix of `openMarker`, return the index where
    /// that prefix begins (so it can stay in the buffer for the next chunk).
    private static func partialOpenSuffixIndex(in s: String) -> String.Index? {
        let m = openMarker
        var len = m.count - 1
        while len > 0 {
            let suffix = m.prefix(len)
            if s.hasSuffix(suffix) {
                return s.index(s.endIndex, offsetBy: -len)
            }
            len -= 1
        }
        return nil
    }
}
```

- [ ] **Step 4: Run, confirm green**

Run: `cd ios/Packages/Networking && swift test 2>&1 | tail -10`
Expected: `Executed 7 tests, with 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/Networking
git commit -m "feat(networking): CheckpointExtractor with cross-chunk buffering"
```

---

### Task 34: `JSONBlockExtractor` — pull final ` ```json ... ``` ` block from full text

**Files:**
- Create: `ios/Packages/Networking/Sources/Networking/SSE/JSONBlockExtractor.swift`
- Create: `ios/Packages/Networking/Tests/NetworkingTests/JSONBlockExtractorTests.swift`

- [ ] **Step 1: Write failing test**

`ios/Packages/Networking/Tests/NetworkingTests/JSONBlockExtractorTests.swift`:
```swift
import XCTest
@testable import Networking

final class JSONBlockExtractorTests: XCTestCase {
    func test_extractsFencedJSONBlock() {
        let text = """
        Here is your plan:

        ```json
        {"workouts": [{"id": "W1"}]}
        ```

        End of message.
        """
        XCTAssertEqual(
            JSONBlockExtractor.extract(from: text),
            #"{"workouts": [{"id": "W1"}]}"#
        )
    }

    func test_extractsLastBlockWhenMultiplePresent() {
        let text = """
        ```json
        {"draft": true}
        ```
        Updated:
        ```json
        {"final": true}
        ```
        """
        XCTAssertEqual(JSONBlockExtractor.extract(from: text), #"{"final": true}"#)
    }

    func test_returnsNilWhenNoBlockPresent() {
        XCTAssertNil(JSONBlockExtractor.extract(from: "no fences here"))
    }
}
```

- [ ] **Step 2: Run, expect failure**

Run: `cd ios/Packages/Networking && swift test 2>&1 | grep -E "cannot find" | head -3`

- [ ] **Step 3: Implement `JSONBlockExtractor`**

`ios/Packages/Networking/Sources/Networking/SSE/JSONBlockExtractor.swift`:
```swift
import Foundation

public enum JSONBlockExtractor {
    /// Extract the LAST ```json fenced code block from the text. Returns the content
    /// without the fences, leading/trailing whitespace trimmed. Nil if no block.
    public static func extract(from text: String) -> String? {
        let pattern = "```json\\s*\\n([\\s\\S]*?)\\n```"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        guard let last = matches.last else { return nil }
        guard let inner = Range(last.range(at: 1), in: text) else { return nil }
        return String(text[inner]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

- [ ] **Step 4: Run, confirm green**

Run: `cd ios/Packages/Networking && swift test 2>&1 | tail -10`
Expected: `Executed 10 tests, with 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/Networking
git commit -m "feat(networking): JSONBlockExtractor (last fenced block, regex-based)"
```

---

### Task 35: Anthropic message types + endpoint factory

**Files:**
- Create: `ios/Packages/Networking/Sources/Networking/Anthropic/AnthropicMessage.swift`
- Create: `ios/Packages/Networking/Sources/Networking/Anthropic/AnthropicRequest.swift`
- Create: `ios/Packages/Networking/Tests/NetworkingTests/AnthropicRequestTests.swift`

- [ ] **Step 1: Write failing test**

`ios/Packages/Networking/Tests/NetworkingTests/AnthropicRequestTests.swift`:
```swift
import XCTest
@testable import Networking

final class AnthropicRequestTests: XCTestCase {
    func test_planGenerationBuilderProducesExpectedShape() throws {
        let req = AnthropicRequest.planGeneration(
            systemPrompt: "You are Pulse.",
            userMessage: "Build today's workout."
        )
        XCTAssertEqual(req.model, "claude-opus-4-7")
        XCTAssertEqual(req.maxTokens, 4096)
        XCTAssertEqual(req.system, "You are Pulse.")
        XCTAssertEqual(req.messages.count, 1)
        XCTAssertEqual(req.messages[0].role, .user)
        // Cache control should be set on system prompt for plan generation
        XCTAssertEqual(req.systemCacheControl, .ephemeral)
    }

    func test_adaptationBuilderUsesOpus() {
        let req = AnthropicRequest.adaptation(
            systemPrompt: "You are Pulse.",
            priorPlanJSON: "{}",
            feedbackJSON: "{}"
        )
        XCTAssertEqual(req.model, "claude-opus-4-7")
        XCTAssertGreaterThan(req.messages.count, 0)
    }

    func test_requestEncodesAsAnthropicWireFormat() throws {
        let req = AnthropicRequest.planGeneration(systemPrompt: "S", userMessage: "U")
        let data = try JSONEncoder().encode(req)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["model"] as? String, "claude-opus-4-7")
        XCTAssertEqual(json["max_tokens"] as? Int, 4096)
        let system = json["system"] as! [[String: Any]]
        XCTAssertEqual(system[0]["type"] as? String, "text")
        XCTAssertEqual((system[0]["cache_control"] as? [String: String])?["type"], "ephemeral")
    }
}
```

- [ ] **Step 2: Run, expect failure**

Run: `cd ios/Packages/Networking && swift test 2>&1 | grep -E "cannot find" | head -3`

- [ ] **Step 3: Implement message types**

`ios/Packages/Networking/Sources/Networking/Anthropic/AnthropicMessage.swift`:
```swift
import Foundation

public struct AnthropicMessage: Codable, Hashable, Sendable {
    public enum Role: String, Codable, Sendable { case user, assistant }
    public let role: Role
    public let content: String

    public init(role: Role, content: String) {
        self.role = role
        self.content = content
    }
}
```

- [ ] **Step 4: Implement request types + factories**

`ios/Packages/Networking/Sources/Networking/Anthropic/AnthropicRequest.swift`:
```swift
import Foundation

public enum CacheControl: String, Sendable {
    case ephemeral
}

public struct AnthropicRequest: Sendable {
    public var model: String
    public var maxTokens: Int
    public var system: String
    public var systemCacheControl: CacheControl?
    public var messages: [AnthropicMessage]
    public var stream: Bool

    public init(model: String, maxTokens: Int, system: String,
                systemCacheControl: CacheControl?, messages: [AnthropicMessage],
                stream: Bool = true) {
        self.model = model
        self.maxTokens = maxTokens
        self.system = system
        self.systemCacheControl = systemCacheControl
        self.messages = messages
        self.stream = stream
    }
}

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

    static func adaptation(systemPrompt: String, priorPlanJSON: String,
                           feedbackJSON: String) -> AnthropicRequest {
        let user = """
        Prior plan:
        \(priorPlanJSON)

        Latest workout feedback:
        \(feedbackJSON)

        Produce an updated plan + diff.
        """
        return AnthropicRequest(
            model: "claude-opus-4-7",
            maxTokens: 4096,
            system: systemPrompt,
            systemCacheControl: .ephemeral,
            messages: [.init(role: .user, content: user)]
        )
    }
}

extension AnthropicRequest: Codable {
    private struct SystemBlock: Codable {
        let type: String
        let text: String
        var cache_control: [String: String]?
    }

    private enum CodingKeys: String, CodingKey {
        case model, max_tokens, system, messages, stream
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(model, forKey: .model)
        try c.encode(maxTokens, forKey: .max_tokens)
        try c.encode(stream, forKey: .stream)
        try c.encode(messages, forKey: .messages)
        var block = SystemBlock(type: "text", text: system, cache_control: nil)
        if let cc = systemCacheControl { block.cache_control = ["type": cc.rawValue] }
        try c.encode([block], forKey: .system)
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.model = try c.decode(String.self, forKey: .model)
        self.maxTokens = try c.decode(Int.self, forKey: .max_tokens)
        self.stream = try c.decodeIfPresent(Bool.self, forKey: .stream) ?? false
        self.messages = try c.decode([AnthropicMessage].self, forKey: .messages)
        let blocks = try c.decode([SystemBlock].self, forKey: .system)
        self.system = blocks.first?.text ?? ""
        self.systemCacheControl = (blocks.first?.cache_control?["type"] == "ephemeral") ? .ephemeral : nil
    }
}
```

- [ ] **Step 5: Run, confirm green**

Run: `cd ios/Packages/Networking && swift test 2>&1 | tail -10`
Expected: `Executed 13 tests, with 0 failures`.

- [ ] **Step 6: Commit**

```bash
git add ios/Packages/Networking
git commit -m "feat(networking): AnthropicMessage + Request with planGen/adaptation factories"
```

---

### Task 36: `APIClient` — URLSession async streaming with auth header injection

**Files:**
- Create: `ios/Packages/Networking/Sources/Networking/APIClient.swift`
- Create: `ios/Packages/Networking/Sources/Networking/APIClientConfig.swift`
- Create: `ios/Packages/Networking/Tests/NetworkingTests/APIClientTests.swift`

- [ ] **Step 1: Write failing test using mock URLProtocol**

`ios/Packages/Networking/Tests/NetworkingTests/APIClientTests.swift`:
```swift
import XCTest
@testable import Networking

final class APIClientTests: XCTestCase {
    override func setUp() {
        MockURLProtocol.reset()
    }

    func test_streamsSSEEventsFromMockedResponse() async throws {
        let body = """
        event: content_block_delta
        data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"hi"}}

        event: message_stop
        data: {"type":"message_stop"}


        """.data(using: .utf8)!
        MockURLProtocol.handler = { req in
            XCTAssertEqual(req.value(forHTTPHeaderField: "X-Device-Token"), "test-token")
            XCTAssertEqual(req.httpMethod, "POST")
            return (HTTPURLResponse(url: req.url!, statusCode: 200,
                                    httpVersion: nil,
                                    headerFields: ["Content-Type": "text/event-stream"])!,
                    body)
        }

        let session = URLSession(configuration: MockURLProtocol.sessionConfig())
        let client = APIClient(config: APIClientConfig(
            workerURL: URL(string: "https://test.workers.dev/")!,
            deviceToken: "test-token"
        ), session: session)

        let request = AnthropicRequest.planGeneration(systemPrompt: "S", userMessage: "U")
        var collected: [SSEEvent] = []
        for try await event in client.streamEvents(request: request) {
            collected.append(event)
        }
        XCTAssertEqual(collected.count, 2)
        XCTAssertEqual(collected[0].event, "content_block_delta")
    }
}

// MARK: - MockURLProtocol

final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    static func reset() { handler = nil }

    static func sessionConfig() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return config
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
```

- [ ] **Step 2: Run, expect failure**

Run: `cd ios/Packages/Networking && swift test 2>&1 | grep -E "cannot find" | head -3`

- [ ] **Step 3: Implement `APIClientConfig`**

`ios/Packages/Networking/Sources/Networking/APIClientConfig.swift`:
```swift
import Foundation

public struct APIClientConfig: Sendable {
    public let workerURL: URL
    public let deviceToken: String

    public init(workerURL: URL, deviceToken: String) {
        self.workerURL = workerURL
        self.deviceToken = deviceToken
    }
}
```

- [ ] **Step 4: Implement `APIClient`**

`ios/Packages/Networking/Sources/Networking/APIClient.swift`:
```swift
import Foundation

public struct APIClient: Sendable {
    public let config: APIClientConfig
    private let session: URLSession

    public init(config: APIClientConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    /// Streams parsed SSE events from the worker proxy. Each yielded event is a complete
    /// SSE record. Errors propagate via the AsyncThrowingStream.
    public func streamEvents(request: AnthropicRequest) -> AsyncThrowingStream<SSEEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var urlRequest = URLRequest(url: config.workerURL)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    urlRequest.setValue(config.deviceToken, forHTTPHeaderField: "X-Device-Token")
                    urlRequest.httpBody = try JSONEncoder().encode(request)

                    let (bytes, response) = try await session.bytes(for: urlRequest)
                    if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                        throw APIClientError.badStatus(http.statusCode)
                    }

                    var parser = SSEStreamParser()
                    var bucket = Data()
                    bucket.reserveCapacity(4096)
                    for try await byte in bytes {
                        bucket.append(byte)
                        if bucket.count >= 1024 {
                            for evt in parser.feed(bucket) { continuation.yield(evt) }
                            bucket.removeAll(keepingCapacity: true)
                        }
                    }
                    if !bucket.isEmpty {
                        for evt in parser.feed(bucket) { continuation.yield(evt) }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

public enum APIClientError: Error, Equatable, Sendable {
    case badStatus(Int)
    case decoding(String)
}
```

- [ ] **Step 5: Run, confirm green**

Run: `cd ios/Packages/Networking && swift test 2>&1 | tail -10`
Expected: `Executed 14 tests, with 0 failures`.

- [ ] **Step 6: Commit**

```bash
git add ios/Packages/Networking
git commit -m "feat(networking): APIClient streams SSE events via URLSession.bytes"
```

---

### Task 37: Retry-with-backoff wrapper for non-streaming errors

**Files:**
- Create: `ios/Packages/Networking/Sources/Networking/RetryPolicy.swift`
- Create: `ios/Packages/Networking/Tests/NetworkingTests/RetryPolicyTests.swift`

- [ ] **Step 1: Write failing test**

`ios/Packages/Networking/Tests/NetworkingTests/RetryPolicyTests.swift`:
```swift
import XCTest
@testable import Networking

final class RetryPolicyTests: XCTestCase {
    func test_succeedsOnFirstAttempt() async throws {
        var attempts = 0
        let result = try await RetryPolicy.default.run {
            attempts += 1
            return 42
        }
        XCTAssertEqual(result, 42)
        XCTAssertEqual(attempts, 1)
    }

    func test_retriesUpToMaxAttemptsOnFailure() async {
        var attempts = 0
        let policy = RetryPolicy(maxAttempts: 3, baseDelay: 0)
        do {
            _ = try await policy.run { () -> Int in
                attempts += 1
                throw URLError(.timedOut)
            }
            XCTFail("expected throw")
        } catch {
            XCTAssertEqual(attempts, 3)
        }
    }

    func test_doesNotRetryNonRetryableErrors() async {
        var attempts = 0
        let policy = RetryPolicy(maxAttempts: 3, baseDelay: 0)
        do {
            _ = try await policy.run { () -> Int in
                attempts += 1
                throw APIClientError.badStatus(401)
            }
            XCTFail("expected throw")
        } catch {
            XCTAssertEqual(attempts, 1)
        }
    }
}
```

- [ ] **Step 2: Run, expect failure**

Run: `cd ios/Packages/Networking && swift test 2>&1 | grep -E "cannot find" | head -3`

- [ ] **Step 3: Implement `RetryPolicy`**

`ios/Packages/Networking/Sources/Networking/RetryPolicy.swift`:
```swift
import Foundation

public struct RetryPolicy: Sendable {
    public let maxAttempts: Int
    public let baseDelay: Double   // seconds; nth retry waits baseDelay * 3^n

    public init(maxAttempts: Int = 3, baseDelay: Double = 1.0) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
    }

    public static let `default` = RetryPolicy()

    public func run<T>(_ operation: () async throws -> T) async throws -> T {
        var lastError: Error?
        for attempt in 0..<maxAttempts {
            do { return try await operation() }
            catch let error where Self.isRetryable(error) {
                lastError = error
                if attempt < maxAttempts - 1 {
                    let delay = baseDelay * pow(3.0, Double(attempt))
                    if delay > 0 {
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    }
                }
            } catch {
                throw error
            }
        }
        throw lastError ?? URLError(.unknown)
    }

    public static func isRetryable(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .notConnectedToInternet,
                 .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return true
            default: return false
            }
        }
        if let apiError = error as? APIClientError {
            if case let .badStatus(code) = apiError {
                return code >= 500
            }
        }
        return false
    }
}
```

- [ ] **Step 4: Run, confirm green**

Run: `cd ios/Packages/Networking && swift test 2>&1 | tail -10`
Expected: `Executed 17 tests, with 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/Networking
git commit -m "feat(networking): RetryPolicy with exponential backoff (3 attempts: 1s/3s/9s)"
```

---

### Task 38: Live worker integration test (gated by env var)

**Files:**
- Create: `ios/Packages/Networking/Tests/NetworkingTests/LiveWorkerSmokeTests.swift`

- [ ] **Step 1: Write the gated live test**

`ios/Packages/Networking/Tests/NetworkingTests/LiveWorkerSmokeTests.swift`:
```swift
import XCTest
@testable import Networking

/// Hits the real worker. Skipped unless PULSE_LIVE_TEST=1 is in env.
/// Reads PULSE_WORKER_URL and PULSE_DEVICE_TOKEN from env.
final class LiveWorkerSmokeTests: XCTestCase {
    func test_liveWorkerStreamsHaikuLikeOutput() async throws {
        let env = ProcessInfo.processInfo.environment
        guard env["PULSE_LIVE_TEST"] == "1" else {
            throw XCTSkip("PULSE_LIVE_TEST != 1")
        }
        let urlStr = try XCTUnwrap(env["PULSE_WORKER_URL"], "PULSE_WORKER_URL missing")
        let token  = try XCTUnwrap(env["PULSE_DEVICE_TOKEN"], "PULSE_DEVICE_TOKEN missing")
        let url    = try XCTUnwrap(URL(string: urlStr))

        let client = APIClient(config: APIClientConfig(workerURL: url, deviceToken: token))
        let req = AnthropicRequest(
            model: "claude-haiku-4-5-20251001",
            maxTokens: 64,
            system: "You are a brief assistant.",
            systemCacheControl: nil,
            messages: [.init(role: .user, content: "Reply with a single word: ping")]
        )

        var sawDelta = false
        var sawStop = false
        for try await event in client.streamEvents(request: req) {
            if event.event == "content_block_delta" { sawDelta = true }
            if event.event == "message_stop" { sawStop = true }
        }
        XCTAssertTrue(sawDelta, "expected at least one content_block_delta")
        XCTAssertTrue(sawStop, "expected message_stop")
    }
}
```

- [ ] **Step 2: Run gated (live) — only when explicitly opted in**

Run from repo root:
```bash
set -a; source worker/.dev.vars; set +a
PULSE_LIVE_TEST=1 \
  PULSE_WORKER_URL="${WORKER_URL:-https://pulse-proxy.smwein.workers.dev/}" \
  PULSE_DEVICE_TOKEN="$DEVICE_TOKEN" \
  swift test --package-path ios/Packages/Networking \
    --filter LiveWorkerSmokeTests 2>&1 | tail -15
```
Expected: `Executed 1 test, with 0 failures` (test runs because env is set). Confirms the live worker is reachable, accepts the device token, and streams Anthropic SSE events end-to-end.

- [ ] **Step 3: Run normal `swift test` confirms the live test is skipped**

Run: `cd ios/Packages/Networking && swift test 2>&1 | grep -E "Executed|skipped" | tail -3`
Expected: skipped (or marked as `XCTSkip`) when `PULSE_LIVE_TEST` is not set; full suite still passes.

- [ ] **Step 4: Commit**

```bash
git add ios/Packages/Networking
git commit -m "test(networking): live worker smoke test (gated by PULSE_LIVE_TEST=1)"
```

---

## Phase F — Repositories (compose Networking + Persistence)

These wrap the lower-level packages so feature code only depends on `Repositories`. Each repository is an `@Observable` final class so SwiftUI can react to its published state directly.

### Task 39: Replace Repositories stub + AppContainer wiring type

**Files:**
- Modify: `ios/Packages/Repositories/Package.swift`
- Delete: `ios/Packages/Repositories/Sources/Repositories/Repositories.swift`
- Create: `ios/Packages/Repositories/Sources/Repositories/Module.swift`
- Create: `ios/Packages/Repositories/Sources/Repositories/AppContainer.swift`
- Create: `ios/Packages/Repositories/Tests/RepositoriesTests/SmokeTests.swift`

- [ ] **Step 1: Replace Package.swift**

`ios/Packages/Repositories/Package.swift`:
```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Repositories",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "Repositories", targets: ["Repositories"])],
    dependencies: [
        .package(path: "../CoreModels"),
        .package(path: "../Persistence"),
        .package(path: "../Networking"),
    ],
    targets: [
        .target(
            name: "Repositories",
            dependencies: ["CoreModels", "Persistence", "Networking"]
        ),
        .testTarget(name: "RepositoriesTests", dependencies: ["Repositories"]),
    ]
)
```

- [ ] **Step 2: Replace stub source**

Run: `rm ios/Packages/Repositories/Sources/Repositories/Repositories.swift`

`ios/Packages/Repositories/Sources/Repositories/Module.swift`:
```swift
// Repositories — UI-facing facade over Persistence + Networking.
```

`ios/Packages/Repositories/Sources/Repositories/AppContainer.swift`:
```swift
import Foundation
import SwiftData
import Networking

/// Single point of injection for repository dependencies. The app target builds
/// one of these in `@main` and hands it to the SwiftUI environment.
public struct AppContainer: Sendable {
    public let modelContainer: ModelContainer
    public let api: APIClient

    public init(modelContainer: ModelContainer, api: APIClient) {
        self.modelContainer = modelContainer
        self.api = api
    }
}
```

- [ ] **Step 3: Smoke test**

`ios/Packages/Repositories/Tests/RepositoriesTests/SmokeTests.swift`:
```swift
import XCTest
@testable import Repositories

final class SmokeTests: XCTestCase {
    func test_packageImports() {
        XCTAssertTrue(true)
    }
}
```

- [ ] **Step 4: Run**

Run: `cd ios/Packages/Repositories && swift test 2>&1 | tail -10`
Expected: `Executed 1 test, with 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/Repositories
git commit -m "feat(repositories): initialize package + AppContainer wiring type"
```

---

### Task 40: `ExerciseAssetRepository` — fetch + cache R2 manifest

**Files:**
- Create: `ios/Packages/Repositories/Sources/Repositories/ExerciseAssetRepository.swift`
- Create: `ios/Packages/Repositories/Tests/RepositoriesTests/ExerciseAssetRepositoryTests.swift`
- Create: `ios/Packages/Repositories/Tests/RepositoriesTests/Fixtures/manifest-sample.json`
- Modify: `ios/Packages/Repositories/Package.swift` (add resources to test target)

- [ ] **Step 1: Add fixture and resources clause**

`ios/Packages/Repositories/Tests/RepositoriesTests/Fixtures/manifest-sample.json`:
```json
{
  "version": 1,
  "generatedAt": "2026-04-27T12:00:00Z",
  "exercises": [
    {
      "id": "back_squat",
      "name": "Back Squat",
      "focus": "legs",
      "level": "intermediate",
      "kind": "strength",
      "equipment": ["barbell"],
      "videoURL": "https://pub-x.r2.dev/exercises/back_squat.mp4",
      "posterURL": "https://pub-x.r2.dev/exercises/back_squat-poster.jpg",
      "instructions": ["Stand tall", "Descend"]
    },
    {
      "id": "world_greatest_stretch",
      "name": "World's Greatest Stretch",
      "focus": "mobility",
      "level": "all",
      "kind": "mobility",
      "equipment": [],
      "videoURL": "https://pub-x.r2.dev/exercises/world_greatest_stretch.mp4",
      "posterURL": "https://pub-x.r2.dev/exercises/world_greatest_stretch-poster.jpg",
      "instructions": ["Lunge forward"]
    }
  ]
}
```

In `ios/Packages/Repositories/Package.swift`, replace the `.testTarget` with:
```swift
.testTarget(
    name: "RepositoriesTests",
    dependencies: ["Repositories"],
    resources: [.copy("Fixtures")]
),
```

- [ ] **Step 2: Write failing test**

`ios/Packages/Repositories/Tests/RepositoriesTests/ExerciseAssetRepositoryTests.swift`:
```swift
import XCTest
import SwiftData
import Persistence
@testable import Repositories

final class ExerciseAssetRepositoryTests: XCTestCase {
    func test_loadManifestPersistsAllAssets() async throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "manifest-sample", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let container = try PulseModelContainer.inMemory()
        let repo = ExerciseAssetRepository(modelContainer: container,
                                           manifestURL: URL(string: "https://example.test/m.json")!,
                                           fetcher: { _ in data })
        try await repo.refreshFromManifest()
        let all = try repo.allAssets()
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(repo.lookup(id: "back_squat")?.name, "Back Squat")
    }

    func test_refreshIsIdempotent_doesNotDuplicate() async throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "manifest-sample", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let container = try PulseModelContainer.inMemory()
        let repo = ExerciseAssetRepository(modelContainer: container,
                                           manifestURL: URL(string: "https://example.test/m.json")!,
                                           fetcher: { _ in data })
        try await repo.refreshFromManifest()
        try await repo.refreshFromManifest()
        XCTAssertEqual(try repo.allAssets().count, 2)
    }
}
```

- [ ] **Step 3: Run, expect failure**

Run: `cd ios/Packages/Repositories && swift test 2>&1 | grep -E "cannot find" | head -3`

- [ ] **Step 4: Implement `ExerciseAssetRepository`**

`ios/Packages/Repositories/Sources/Repositories/ExerciseAssetRepository.swift`:
```swift
import Foundation
import SwiftData
import Persistence

public typealias DataFetcher = @Sendable (URL) async throws -> Data

@MainActor
public final class ExerciseAssetRepository {
    public let modelContainer: ModelContainer
    public let manifestURL: URL
    private let fetcher: DataFetcher

    public init(modelContainer: ModelContainer, manifestURL: URL,
                fetcher: @escaping DataFetcher = Self.urlSessionFetcher) {
        self.modelContainer = modelContainer
        self.manifestURL = manifestURL
        self.fetcher = fetcher
    }

    public static let urlSessionFetcher: DataFetcher = { url in
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }

    public func refreshFromManifest() async throws {
        let data = try await fetcher(manifestURL)
        let manifest = try JSONDecoder().decode(Manifest.self, from: data)
        let context = modelContainer.mainContext
        for entry in manifest.exercises {
            let id = entry.id
            let descriptor = FetchDescriptor<ExerciseAssetEntity>(
                predicate: #Predicate { $0.id == id }
            )
            if let existing = try context.fetch(descriptor).first {
                existing.name = entry.name
                existing.focus = entry.focus
                existing.level = entry.level
                existing.kind = entry.kind
                existing.equipment = entry.equipment
                existing.videoURL = entry.videoURL
                existing.posterURL = entry.posterURL
                existing.instructionsJSON = (try? JSONEncoder().encode(entry.instructions)) ?? Data()
                existing.manifestVersion = manifest.version
            } else {
                let asset = ExerciseAssetEntity(
                    id: entry.id,
                    name: entry.name,
                    focus: entry.focus,
                    level: entry.level,
                    kind: entry.kind,
                    equipment: entry.equipment,
                    videoURL: entry.videoURL,
                    posterURL: entry.posterURL,
                    instructionsJSON: (try? JSONEncoder().encode(entry.instructions)) ?? Data(),
                    manifestVersion: manifest.version
                )
                context.insert(asset)
            }
        }
        try context.save()
    }

    public func allAssets() throws -> [ExerciseAssetEntity] {
        try modelContainer.mainContext.fetch(FetchDescriptor<ExerciseAssetEntity>())
    }

    public func lookup(id: String) -> ExerciseAssetEntity? {
        let descriptor = FetchDescriptor<ExerciseAssetEntity>(predicate: #Predicate { $0.id == id })
        return try? modelContainer.mainContext.fetch(descriptor).first
    }

    // MARK: - Manifest decode types

    private struct Manifest: Decodable {
        let version: Int
        let exercises: [Entry]
    }

    private struct Entry: Decodable {
        let id: String
        let name: String
        let focus: String
        let level: String
        let kind: String
        let equipment: [String]
        let videoURL: URL
        let posterURL: URL
        let instructions: [String]
    }
}
```

- [ ] **Step 5: Run, confirm green**

Run: `cd ios/Packages/Repositories && swift test 2>&1 | tail -10`
Expected: `Executed 3 tests, with 0 failures`.

- [ ] **Step 6: Commit**

```bash
git add ios/Packages/Repositories
git commit -m "feat(repositories): ExerciseAssetRepository (manifest fetch + idempotent persist)"
```

---

### Task 41: `PlanRepository` — generate plan via streaming + persist

**Files:**
- Create: `ios/Packages/Repositories/Sources/Repositories/PlanRepository.swift`
- Create: `ios/Packages/Repositories/Sources/Repositories/PlanGenerationStream.swift`
- Create: `ios/Packages/Repositories/Tests/RepositoriesTests/PlanRepositoryTests.swift`

- [ ] **Step 1: Write failing test**

`ios/Packages/Repositories/Tests/RepositoriesTests/PlanRepositoryTests.swift`:
```swift
import XCTest
import SwiftData
import CoreModels
import Networking
import Persistence
@testable import Repositories

final class PlanRepositoryTests: XCTestCase {
    func test_listLatestReturnsMostRecentPlanFirst() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let older = PlanEntity(id: UUID(), weekStart: Date(timeIntervalSince1970: 1_700_000_000),
                               generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
                               modelUsed: "claude-opus-4-7", promptTokens: 100,
                               completionTokens: 100, payloadJSON: Data("{}".utf8))
        let newer = PlanEntity(id: UUID(), weekStart: Date(timeIntervalSince1970: 1_730_000_000),
                               generatedAt: Date(timeIntervalSince1970: 1_730_000_000),
                               modelUsed: "claude-opus-4-7", promptTokens: 100,
                               completionTokens: 100, payloadJSON: Data("{}".utf8))
        ctx.insert(older); ctx.insert(newer); try ctx.save()

        let repo = PlanRepository.makeForTests(modelContainer: container)
        let latest = try repo.listLatest(limit: 5)
        XCTAssertEqual(latest.first?.id, newer.id)
    }
}
```

- [ ] **Step 2: Run, expect failure**

Run: `cd ios/Packages/Repositories && swift test 2>&1 | grep -E "cannot find" | head -3`

- [ ] **Step 3: Implement `PlanGenerationStream` value type**

`ios/Packages/Repositories/Sources/Repositories/PlanGenerationStream.swift`:
```swift
import Foundation
import CoreModels

/// Live updates from a plan-generation request. UI subscribes to this stream
/// and renders thinking-state checkpoints + the final parsed plan.
public enum PlanStreamUpdate: Sendable {
    case checkpoint(String)
    case textDelta(String)              // user-visible passthrough text
    case done(WorkoutPlan, modelUsed: String, promptTokens: Int, completionTokens: Int)
}
```

- [ ] **Step 4: Implement `PlanRepository`**

`ios/Packages/Repositories/Sources/Repositories/PlanRepository.swift`:
```swift
import Foundation
import SwiftData
import CoreModels
import Networking
import Persistence

@MainActor
public final class PlanRepository {
    public let modelContainer: ModelContainer
    private let api: APIClient?

    public init(modelContainer: ModelContainer, api: APIClient) {
        self.modelContainer = modelContainer
        self.api = api
    }

    /// Test-only initializer. Bypasses APIClient — use only for read-side tests.
    public static func makeForTests(modelContainer: ModelContainer) -> PlanRepository {
        PlanRepository(modelContainer: modelContainer, api: nil)
    }

    private init(modelContainer: ModelContainer, api: APIClient?) {
        self.modelContainer = modelContainer
        self.api = api
    }

    public func listLatest(limit: Int = 5) throws -> [PlanEntity] {
        var descriptor = FetchDescriptor<PlanEntity>(
            sortBy: [SortDescriptor(\.generatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try modelContainer.mainContext.fetch(descriptor)
    }

    /// Streams a plan generation, yielding incremental updates. The final `.done`
    /// case carries the parsed plan; the repository persists it before yielding.
    public func generatePlan(systemPrompt: String, userMessage: String,
                             weekStart: Date) -> AsyncThrowingStream<PlanStreamUpdate, Error> {
        guard let api else {
            return AsyncThrowingStream { $0.finish(throwing: APIClientError.badStatus(0)) }
        }
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = AnthropicRequest.planGeneration(
                        systemPrompt: systemPrompt,
                        userMessage: userMessage
                    )
                    var fullText = ""
                    var modelUsed = "claude-opus-4-7"
                    var promptTokens = 0
                    var completionTokens = 0
                    var checkpoints = CheckpointExtractor()

                    for try await event in api.streamEvents(request: request) {
                        switch event.event {
                        case "message_start":
                            if let dict = try? JSONSerialization.jsonObject(with: Data(event.data.utf8)) as? [String: Any],
                               let msg = dict["message"] as? [String: Any] {
                                if let m = msg["model"] as? String { modelUsed = m }
                            }
                        case "content_block_delta":
                            if let text = Self.extractTextDelta(eventData: event.data) {
                                fullText.append(text)
                                let result = checkpoints.feed(text)
                                for cp in result.checkpoints {
                                    continuation.yield(.checkpoint(cp))
                                }
                                if !result.passthroughText.isEmpty {
                                    continuation.yield(.textDelta(result.passthroughText))
                                }
                            }
                        case "message_delta":
                            if let dict = try? JSONSerialization.jsonObject(with: Data(event.data.utf8)) as? [String: Any],
                               let usage = dict["usage"] as? [String: Any] {
                                if let p = usage["input_tokens"] as? Int { promptTokens = p }
                                if let c = usage["output_tokens"] as? Int { completionTokens = c }
                            }
                        case "message_stop":
                            guard let json = JSONBlockExtractor.extract(from: fullText),
                                  let data = json.data(using: .utf8) else {
                                throw APIClientError.decoding("no fenced ```json block in stream")
                            }
                            let plan = try JSONDecoder.pulse.decode(WorkoutPlan.self, from: data)
                            try persist(plan: plan, weekStart: weekStart, modelUsed: modelUsed,
                                        promptTokens: promptTokens, completionTokens: completionTokens,
                                        rawJSON: data)
                            continuation.yield(.done(plan, modelUsed: modelUsed,
                                                    promptTokens: promptTokens,
                                                    completionTokens: completionTokens))
                            continuation.finish()
                            return
                        default: break
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

    private func persist(plan: WorkoutPlan, weekStart: Date, modelUsed: String,
                         promptTokens: Int, completionTokens: Int, rawJSON: Data) throws {
        let entity = PlanEntity(
            id: UUID(),
            weekStart: weekStart,
            generatedAt: Date(),
            modelUsed: modelUsed,
            promptTokens: promptTokens,
            completionTokens: completionTokens,
            payloadJSON: rawJSON
        )
        let ctx = modelContainer.mainContext
        ctx.insert(entity)
        try ctx.save()
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
```

- [ ] **Step 5: Run, confirm green**

Run: `cd ios/Packages/Repositories && swift test 2>&1 | tail -10`
Expected: `Executed 4 tests, with 0 failures`.

- [ ] **Step 6: Commit**

```bash
git add ios/Packages/Repositories
git commit -m "feat(repositories): PlanRepository — streaming generation + persist"
```

---

### Task 42: `WorkoutRepository` — todaysWorkout + status updates

**Files:**
- Create: `ios/Packages/Repositories/Sources/Repositories/WorkoutRepository.swift`
- Create: `ios/Packages/Repositories/Tests/RepositoriesTests/WorkoutRepositoryTests.swift`

- [ ] **Step 1: Write failing test**

`ios/Packages/Repositories/Tests/RepositoriesTests/WorkoutRepositoryTests.swift`:
```swift
import XCTest
import SwiftData
import Persistence
@testable import Repositories

final class WorkoutRepositoryTests: XCTestCase {
    func test_todaysWorkoutReturnsScheduledForToday() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let cal = Calendar(identifier: .gregorian)
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!

        for date in [yesterday, today, tomorrow] {
            ctx.insert(WorkoutEntity(
                id: UUID(),
                planID: UUID(),
                scheduledFor: date,
                title: "T\(date.timeIntervalSince1970)",
                subtitle: "",
                workoutType: "Strength",
                durationMin: 30,
                status: "scheduled",
                blocksJSON: Data("[]".utf8),
                exercisesJSON: Data("[]".utf8)
            ))
        }
        try ctx.save()

        let repo = WorkoutRepository(modelContainer: container)
        let result = try repo.todaysWorkout(now: today.addingTimeInterval(60 * 60 * 4))
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.title.hasPrefix("T\(today.timeIntervalSince1970)"), true)
    }

    func test_markCompletedUpdatesStatus() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let w = WorkoutEntity(
            id: UUID(),
            planID: UUID(),
            scheduledFor: Date(),
            title: "x",
            subtitle: "",
            workoutType: "Strength",
            durationMin: 30,
            status: "scheduled",
            blocksJSON: Data("[]".utf8),
            exercisesJSON: Data("[]".utf8)
        )
        ctx.insert(w); try ctx.save()
        let repo = WorkoutRepository(modelContainer: container)
        try repo.markCompleted(workoutID: w.id)
        let fetched = try ctx.fetch(FetchDescriptor<WorkoutEntity>()).first
        XCTAssertEqual(fetched?.status, "completed")
    }
}
```

- [ ] **Step 2: Run, expect failure**

Run: `cd ios/Packages/Repositories && swift test 2>&1 | grep -E "cannot find" | head -3`

- [ ] **Step 3: Implement `WorkoutRepository`**

`ios/Packages/Repositories/Sources/Repositories/WorkoutRepository.swift`:
```swift
import Foundation
import SwiftData
import Persistence

@MainActor
public final class WorkoutRepository {
    public let modelContainer: ModelContainer

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    public func todaysWorkout(now: Date = Date(),
                              calendar: Calendar = Calendar(identifier: .gregorian))
                              throws -> WorkoutEntity? {
        let dayStart = calendar.startOfDay(for: now)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        let descriptor = FetchDescriptor<WorkoutEntity>(
            predicate: #Predicate {
                $0.scheduledFor >= dayStart && $0.scheduledFor < dayEnd
            },
            sortBy: [SortDescriptor(\.scheduledFor, order: .forward)]
        )
        return try modelContainer.mainContext.fetch(descriptor).first
    }

    public func markCompleted(workoutID: UUID) throws {
        let ctx = modelContainer.mainContext
        let descriptor = FetchDescriptor<WorkoutEntity>(
            predicate: #Predicate { $0.id == workoutID }
        )
        guard let w = try ctx.fetch(descriptor).first else { return }
        w.status = "completed"
        try ctx.save()
    }
}
```

- [ ] **Step 4: Run, confirm green**

Run: `cd ios/Packages/Repositories && swift test 2>&1 | tail -10`
Expected: `Executed 6 tests, with 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/Repositories
git commit -m "feat(repositories): WorkoutRepository (todaysWorkout + markCompleted)"
```

---

### Task 43: `FeedbackRepository` — save + adaptation streaming

**Files:**
- Create: `ios/Packages/Repositories/Sources/Repositories/FeedbackRepository.swift`
- Create: `ios/Packages/Repositories/Tests/RepositoriesTests/FeedbackRepositoryTests.swift`

- [ ] **Step 1: Write failing test for save path (offline-only logic, no streaming yet)**

`ios/Packages/Repositories/Tests/RepositoriesTests/FeedbackRepositoryTests.swift`:
```swift
import XCTest
import SwiftData
import CoreModels
import Persistence
@testable import Repositories

final class FeedbackRepositoryTests: XCTestCase {
    func test_saveFeedbackPersistsAndAttachesToSession() throws {
        let container = try PulseModelContainer.inMemory()
        let ctx = container.mainContext
        let session = SessionEntity(id: UUID(), workoutID: UUID(), startedAt: Date())
        ctx.insert(session); try ctx.save()

        let repo = FeedbackRepository.makeForTests(modelContainer: container)
        let fb = WorkoutFeedback(
            sessionID: session.id,
            submittedAt: Date(),
            rating: 4,
            intensity: 3,
            mood: .good,
            tags: ["energized"],
            exerciseRatings: ["back_squat": .up],
            note: nil
        )
        try repo.saveFeedback(fb)

        let fetched = try ctx.fetch(FetchDescriptor<FeedbackEntity>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.session?.id, session.id)
    }
}
```

- [ ] **Step 2: Run, expect failure**

Run: `cd ios/Packages/Repositories && swift test 2>&1 | grep -E "cannot find" | head -3`

- [ ] **Step 3: Implement `FeedbackRepository`**

`ios/Packages/Repositories/Sources/Repositories/FeedbackRepository.swift`:
```swift
import Foundation
import SwiftData
import CoreModels
import Networking
import Persistence

public enum AdaptationStreamUpdate: Sendable {
    case checkpoint(String)
    case textDelta(String)
    case done(AdaptationDiff, modelUsed: String, promptTokens: Int, completionTokens: Int)
}

@MainActor
public final class FeedbackRepository {
    public let modelContainer: ModelContainer
    private let api: APIClient?

    public init(modelContainer: ModelContainer, api: APIClient) {
        self.modelContainer = modelContainer
        self.api = api
    }

    public static func makeForTests(modelContainer: ModelContainer) -> FeedbackRepository {
        FeedbackRepository(modelContainer: modelContainer, api: nil)
    }

    private init(modelContainer: ModelContainer, api: APIClient?) {
        self.modelContainer = modelContainer
        self.api = api
    }

    public func saveFeedback(_ feedback: WorkoutFeedback) throws {
        let ctx = modelContainer.mainContext
        let sessionID = feedback.sessionID
        let sessionDescriptor = FetchDescriptor<SessionEntity>(
            predicate: #Predicate { $0.id == sessionID }
        )
        let session = try ctx.fetch(sessionDescriptor).first

        let exData = (try? JSONEncoder().encode(feedback.exerciseRatings)) ?? Data()
        let entity = FeedbackEntity(
            id: UUID(),
            session: session,
            submittedAt: feedback.submittedAt,
            rating: feedback.rating,
            intensity: feedback.intensity,
            mood: feedback.mood.rawValue,
            tags: feedback.tags,
            exRatingsJSON: exData,
            note: feedback.note
        )
        ctx.insert(entity)
        try ctx.save()
    }

    /// Streams an adaptation request. The final `.done` carries the parsed diff;
    /// the repository persists an AdaptationEntity before yielding.
    public func adaptPlan(systemPrompt: String,
                          priorPlanJSON: String,
                          feedbackJSON: String,
                          appliedToPlanID: UUID,
                          feedbackID: UUID) -> AsyncThrowingStream<AdaptationStreamUpdate, Error> {
        guard let api else {
            return AsyncThrowingStream { $0.finish(throwing: APIClientError.badStatus(0)) }
        }
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = AnthropicRequest.adaptation(
                        systemPrompt: systemPrompt,
                        priorPlanJSON: priorPlanJSON,
                        feedbackJSON: feedbackJSON
                    )
                    var fullText = ""
                    var modelUsed = "claude-opus-4-7"
                    var promptTokens = 0
                    var completionTokens = 0
                    var checkpoints = CheckpointExtractor()

                    for try await event in api.streamEvents(request: request) {
                        switch event.event {
                        case "content_block_delta":
                            if let text = Self.extractTextDelta(eventData: event.data) {
                                fullText.append(text)
                                let result = checkpoints.feed(text)
                                for cp in result.checkpoints { continuation.yield(.checkpoint(cp)) }
                                if !result.passthroughText.isEmpty {
                                    continuation.yield(.textDelta(result.passthroughText))
                                }
                            }
                        case "message_delta":
                            if let dict = try? JSONSerialization.jsonObject(with: Data(event.data.utf8)) as? [String: Any],
                               let usage = dict["usage"] as? [String: Any] {
                                if let p = usage["input_tokens"] as? Int { promptTokens = p }
                                if let c = usage["output_tokens"] as? Int { completionTokens = c }
                            }
                        case "message_stop":
                            guard let json = JSONBlockExtractor.extract(from: fullText),
                                  let data = json.data(using: .utf8) else {
                                throw APIClientError.decoding("no fenced ```json block")
                            }
                            let diff = try JSONDecoder.pulse.decode(AdaptationDiff.self, from: data)
                            try persist(diff: diff, feedbackID: feedbackID, planID: appliedToPlanID,
                                        modelUsed: modelUsed, promptTokens: promptTokens,
                                        completionTokens: completionTokens, rawJSON: data)
                            continuation.yield(.done(diff, modelUsed: modelUsed,
                                                    promptTokens: promptTokens,
                                                    completionTokens: completionTokens))
                            continuation.finish()
                            return
                        default: break
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

    private func persist(diff: AdaptationDiff, feedbackID: UUID, planID: UUID,
                         modelUsed: String, promptTokens: Int, completionTokens: Int,
                         rawJSON: Data) throws {
        let entity = AdaptationEntity(
            id: UUID(),
            feedbackID: feedbackID,
            appliedToPlanID: planID,
            generatedAt: Date(),
            modelUsed: modelUsed,
            promptTokens: promptTokens,
            completionTokens: completionTokens,
            diffJSON: rawJSON,
            rationale: diff.rationale
        )
        let ctx = modelContainer.mainContext
        ctx.insert(entity)
        try ctx.save()
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
```

- [ ] **Step 4: Run, confirm green**

Run: `cd ios/Packages/Repositories && swift test 2>&1 | tail -10`
Expected: `Executed 7 tests, with 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add ios/Packages/Repositories
git commit -m "feat(repositories): FeedbackRepository (save + adaptPlan streaming)"
```

---

## Phase G — App Shell Wire-Up

### Task 44: `AppShell` package — root scaffold + theme provider

**Files:**
- Modify: `ios/Packages/AppShell/Package.swift`
- Delete: `ios/Packages/AppShell/Sources/AppShell/AppShell.swift`
- Create: `ios/Packages/AppShell/Sources/AppShell/RootScaffold.swift`
- Create: `ios/Packages/AppShell/Sources/AppShell/PulseTabBar.swift`
- Create: `ios/Packages/AppShell/Tests/AppShellTests/SmokeTests.swift`

- [ ] **Step 1: Replace Package.swift**

`ios/Packages/AppShell/Package.swift`:
```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AppShell",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "AppShell", targets: ["AppShell"])],
    dependencies: [
        .package(path: "../DesignSystem"),
        .package(path: "../Repositories"),
    ],
    targets: [
        .target(name: "AppShell", dependencies: ["DesignSystem", "Repositories"]),
        .testTarget(name: "AppShellTests", dependencies: ["AppShell"]),
    ]
)
```

- [ ] **Step 2: Replace stub source**

Run: `rm ios/Packages/AppShell/Sources/AppShell/AppShell.swift`

- [ ] **Step 3: Implement `RootScaffold`**

`ios/Packages/AppShell/Sources/AppShell/RootScaffold.swift`:
```swift
import SwiftUI
import DesignSystem
import Repositories

public struct RootScaffold<DebugContent: View>: View {
    @State private var selectedTab: PulseTab = .today
    private let appContainer: AppContainer
    private let themeStore: ThemeStore
    private let debugContent: () -> DebugContent

    public init(appContainer: AppContainer, themeStore: ThemeStore,
                @ViewBuilder debugContent: @escaping () -> DebugContent) {
        self.appContainer = appContainer
        self.themeStore = themeStore
        self.debugContent = debugContent
    }

    public var body: some View {
        ZStack {
            PulseColors.bg0.color.ignoresSafeArea()
            VStack(spacing: 0) {
                TopBar(eyebrow: "PULSE", title: tabTitle) {
                    IconButton(systemName: "wrench.and.screwdriver") {
                        selectedTab = .debug
                    }
                }
                Group {
                    switch selectedTab {
                    case .today: todayPlaceholder
                    case .progress: progressPlaceholder
                    case .debug: debugContent()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                PulseTabBar(selected: $selectedTab)
            }
        }
        .pulseTheme(themeStore)
        .preferredColorScheme(.dark)
    }

    private var tabTitle: String {
        switch selectedTab {
        case .today:    return "Today"
        case .progress: return "Progress"
        case .debug:    return "Debug"
        }
    }

    private var todayPlaceholder: some View {
        ScrollView {
            VStack(spacing: PulseSpacing.lg) {
                PulseCard {
                    VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                        Text("Today")
                            .pulseFont(.h2)
                            .foregroundStyle(PulseColors.ink0.color)
                        Text("Plan 2 foundation shell. Real feature ships in Plan 3.")
                            .pulseFont(.body)
                            .foregroundStyle(PulseColors.ink2.color)
                    }
                }
                ExercisePlaceholder(label: "PREVIEW")
                    .frame(height: 220)
            }
            .padding(PulseSpacing.lg)
        }
    }

    private var progressPlaceholder: some View {
        VStack(spacing: PulseSpacing.lg) {
            Ring(progress: 0.42)
            Text("Weekly ring (placeholder)")
                .pulseFont(.small)
                .foregroundStyle(PulseColors.ink2.color)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

- [ ] **Step 4: Implement `PulseTabBar`**

`ios/Packages/AppShell/Sources/AppShell/PulseTabBar.swift`:
```swift
import SwiftUI
import DesignSystem

public enum PulseTab: Hashable {
    case today, progress, debug
}

public struct PulseTabBar: View {
    @Binding public var selected: PulseTab
    @Environment(\.pulseTheme) private var theme

    public init(selected: Binding<PulseTab>) {
        self._selected = selected
    }

    public var body: some View {
        HStack(spacing: PulseSpacing.sm) {
            tabButton(.today, label: "Today", systemImage: "flame")
            tabButton(.progress, label: "Progress", systemImage: "chart.line.uptrend.xyaxis")
            tabButton(.debug, label: "Debug", systemImage: "ladybug")
        }
        .padding(.horizontal, PulseSpacing.lg)
        .padding(.vertical, PulseSpacing.sm)
        .background(PulseColors.bg1.color)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(PulseColors.line.color)
                .frame(maxHeight: .infinity, alignment: .top)
        )
    }

    private func tabButton(_ tab: PulseTab, label: String, systemImage: String) -> some View {
        Button {
            selected = tab
        } label: {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .regular))
                Text(label).pulseFont(.eyebrow)
            }
            .foregroundStyle(selected == tab ? theme.accent.base.color : PulseColors.ink2.color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, PulseSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: PulseRadius.sm)
                    .fill(selected == tab ? PulseColors.bg2.color : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 5: Smoke test**

`ios/Packages/AppShell/Tests/AppShellTests/SmokeTests.swift`:
```swift
import XCTest
@testable import AppShell

final class SmokeTests: XCTestCase {
    func test_packageImports() {
        XCTAssertTrue(true)
    }
}
```

- [ ] **Step 6: Run**

Run: `cd ios/Packages/AppShell && swift test 2>&1 | tail -10`
Expected: `Executed 1 test, with 0 failures`.

- [ ] **Step 7: Commit**

```bash
git add ios/Packages/AppShell
git commit -m "feat(app-shell): RootScaffold + PulseTabBar with theme injection"
```

---

### Task 45: App target wires `AppContainer` + `ThemeStore` and renders `RootScaffold`

**Files:**
- Modify: `ios/PulseApp/PulseApp.swift`
- Create: `ios/PulseApp/AppShellRoot.swift`

- [ ] **Step 1: Implement the wire-up view**

`ios/PulseApp/AppShellRoot.swift`:
```swift
import SwiftUI
import SwiftData
import DesignSystem
import Networking
import Persistence
import Repositories
import AppShell

struct AppShellRoot: View {
    let appContainer: AppContainer
    let themeStore: ThemeStore

    var body: some View {
        RootScaffold(appContainer: appContainer, themeStore: themeStore) {
            DebugStreamView(api: appContainer.api, themeStore: themeStore)
        }
    }
}
```

- [ ] **Step 2: Replace `PulseApp.swift`**

`ios/PulseApp/PulseApp.swift`:
```swift
import SwiftUI
import SwiftData
import DesignSystem
import Networking
import Persistence
import Repositories

@main
struct PulseApp: App {
    @State private var container = makeAppContainer()
    @State private var theme = ThemeStore(activeCoachID: "ace")

    var body: some Scene {
        WindowGroup {
            AppShellRoot(appContainer: container, themeStore: theme)
                .modelContainer(container.modelContainer)
        }
    }

    private static func makeAppContainer() -> AppContainer {
        let modelContainer: ModelContainer
        do {
            let url = URL.applicationSupportDirectory.appending(path: "pulse.sqlite")
            try? FileManager.default.createDirectory(
                at: URL.applicationSupportDirectory,
                withIntermediateDirectories: true
            )
            modelContainer = try PulseModelContainer.onDisk(url: url)
        } catch {
            assertionFailure("Persistence setup failed: \(error). Falling back to in-memory.")
            modelContainer = try! PulseModelContainer.inMemory()
        }
        let api = APIClient(config: APIClientConfig(
            workerURL: Secrets.workerURL,
            deviceToken: Secrets.deviceToken
        ))
        return AppContainer(modelContainer: modelContainer, api: api)
    }
}
```

- [ ] **Step 3: Bake secrets and re-generate the Xcode project**

Run from repo root:
```bash
./scripts/bake-secrets.sh
cd ios && xcodegen generate
```
Expected: `baked: …/Secrets.swift` then `Created project at …/PulseApp.xcodeproj`.

- [ ] **Step 4: Build (DebugStreamView still missing — expect failure)**

Run:
```bash
xcodebuild -project ios/PulseApp.xcodeproj -scheme PulseApp \
  -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -10
```
Expected: build error mentioning `DebugStreamView`. That ships in Task 46.

- [ ] **Step 5: Commit (build is intentionally red — Task 46 closes the loop)**

```bash
git add ios/PulseApp
git commit -m "feat(ios): wire AppContainer + ThemeStore into PulseApp @main scene"
```

---

### Task 46: `DebugStreamView` — calls live worker, renders SSE in mono console

**Files:**
- Create: `ios/PulseApp/DebugStreamView.swift`

- [ ] **Step 1: Implement `DebugStreamView`**

`ios/PulseApp/DebugStreamView.swift`:
```swift
import SwiftUI
import DesignSystem
import Networking

struct DebugStreamView: View {
    let api: APIClient
    let themeStore: ThemeStore

    @State private var lines: [String] = ["⟦ ready ⟧"]
    @State private var inFlight = false
    @State private var selectedCoach: String = "ace"

    var body: some View {
        VStack(spacing: PulseSpacing.md) {
            HStack(spacing: PulseSpacing.sm) {
                ForEach(["ace", "rex", "vera", "mira"], id: \.self) { id in
                    PulsePill(id.uppercased(), variant: selectedCoach == id ? .accent : .default)
                        .onTapGesture {
                            selectedCoach = id
                            themeStore.setActiveCoach(id: id)
                        }
                }
            }

            consoleView

            PulseButton(inFlight ? "Streaming…" : "Ping worker",
                        variant: .primary, size: .large) {
                Task { await runSmoke() }
            }
            .disabled(inFlight)
            .opacity(inFlight ? 0.6 : 1)
        }
        .padding(PulseSpacing.lg)
    }

    private var consoleView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .pulseFont(.mono)
                        .foregroundStyle(PulseColors.ink1.color)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(PulseSpacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: PulseRadius.md, style: .continuous)
                .fill(PulseColors.bg1.color)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadius.md, style: .continuous)
                .strokeBorder(PulseColors.line.color, lineWidth: 1)
        )
    }

    private func runSmoke() async {
        inFlight = true
        defer { inFlight = false }
        lines.removeAll()
        lines.append("⟦ POST \(api.config.workerURL.absoluteString) ⟧")

        let request = AnthropicRequest(
            model: "claude-haiku-4-5-20251001",
            maxTokens: 64,
            system: "You are a brief assistant.",
            systemCacheControl: nil,
            messages: [.init(role: .user, content: "Say a one-word greeting.")]
        )
        do {
            for try await event in api.streamEvents(request: request) {
                let snippet = event.data.prefix(80)
                lines.append("· \(event.event): \(snippet)")
            }
            lines.append("⟦ done ⟧")
        } catch {
            lines.append("✗ \(String(describing: error))")
        }
    }
}
```

- [ ] **Step 2: Re-build**

Run:
```bash
xcodebuild -project ios/PulseApp.xcodeproj -scheme PulseApp \
  -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -10
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Boot a simulator, install, and launch**

Run from repo root:
```bash
SIM_ID=$(xcrun simctl list devices available | \
  grep -E "iPhone 1[5-9]|iPhone 2[0-9]" | head -1 | sed -E 's/.*\(([0-9A-F-]+)\).*/\1/')
xcrun simctl boot "$SIM_ID" 2>/dev/null || true
open -a Simulator

xcodebuild -project ios/PulseApp.xcodeproj -scheme PulseApp \
  -destination "platform=iOS Simulator,id=$SIM_ID" \
  -derivedDataPath ios/DerivedData build 2>&1 | tail -3

APP_PATH="ios/DerivedData/Build/Products/Debug-iphonesimulator/PulseApp.app"
xcrun simctl install "$SIM_ID" "$APP_PATH"
xcrun simctl launch "$SIM_ID" co.simpleav.pulse
```
Expected: simulator launches the app showing the "Today" tab. Tap the wrench icon → DebugStreamView. Tap a coach pill (ACE/REX/VERA/MIRA) — the accent color across the app updates immediately. Tap "Ping worker" — console renders SSE event names from a live Haiku response.

> If the live ping fails with status 403, re-run `./scripts/bake-secrets.sh` and rebuild — the device token may have rotated.

- [ ] **Step 4: Commit**

```bash
git add ios/PulseApp/DebugStreamView.swift
git commit -m "feat(ios): DebugStreamView — live worker SSE smoke + coach picker"
```

---

### Task 47: Plan 2 acceptance — manual smoke checklist + summary commit

**Files:**
- Create: `ios/README.md`

- [ ] **Step 1: Author `ios/README.md` with the dev workflow + smoke checklist**

`ios/README.md`:
```markdown
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
```

- [ ] **Step 2: Walk the checklist on a real simulator**

Run through every checkbox in the smoke checklist above. If anything fails, fix it (no placeholders — root cause + commit before moving on).

- [ ] **Step 3: Push to origin**

Run from repo root:
```bash
git status
git push origin main
```
Expected: branch up to date with origin, no uncommitted changes.

- [ ] **Step 4: Commit `ios/README.md`**

```bash
git add ios/README.md
git commit -m "docs(ios): add Plan 2 acceptance checklist + iOS dev workflow"
git push origin main
```

- [ ] **Step 5: Update memory note marking Plan 2 done**

This is a manual prompt for the agent: after acceptance, ask Claude to update `pulse-current-state.md` to reflect Plan 2 complete and Plan 3 (first user-facing flows) as next.

---

## Plan 2 — done criteria recap

When all 47 tasks are committed and the smoke checklist passes:

- App target builds for iOS 17+ simulator with no warnings or errors
- All six SPM packages have green `swift test` runs
- Live worker pipeline proven via DebugStreamView (manual) + LiveWorkerSmokeTests (automated)
- ThemeStore drives accent across every primitive that uses `pulseTheme`
- SwiftData persists on disk between launches
- Foundation is ready for Plan 3 (Onboarding + Home + PlanGeneration + WorkoutDetail)

