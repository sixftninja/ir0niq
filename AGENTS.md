# Ironiq — iOS + watchOS Gym Tracker
## Codex Project File

---

## Environment

- macOS 26.5 (Sequoia), Apple Silicon (arm64)
- Xcode 26.5 / Build 17F42
- Ruby 4.0.5 (brew)
- Fastlane 2.235.0 (brew)
- Node 22.14.0
- Git 2.50.1

---

## Project Identity

| Key | Value |
|---|---|
| App display name | Ironiq |
| Bundle ID (iOS) | com.ir0niq.app |
| Bundle ID (watchOS) | com.ir0niq.app.watchkitapp |
| Minimum iOS | 17.0 |
| Minimum watchOS | 10.0 |
| Swift version | 6.0 |
| Project root | `~/Developer/Ironiq` |
| Xcode project | `Ironiq.xcodeproj` |

Sensitive credentials (Apple ID, Team ID, etc.) live in `.env` at project root.
Codex must never read, print, log, or transmit `.env` contents.
`.env` is in `.gitignore` — never commit it.

---

## .env Schema

Codex must generate a `.env.template` (no real values) with these keys:

```
APPLE_ID=
TEAM_ID=
APP_STORE_CONNECT_API_KEY_ID=
APP_STORE_CONNECT_API_ISSUER_ID=
APP_STORE_CONNECT_API_KEY_PATH=
MATCH_PASSWORD=
```

The human fills in `.env` manually. Codex reads keys via fastlane's dotenv integration — never echo them.

---

## Architecture

### Targets
- `Ironiq` — iOS 17.0+, iPhone only (no iPad)
- `IroniqWatch` — watchOS 10.0+, Apple Watch SE and newer
- `IroniqTests` — XCTest unit tests
- `IroniqUITests` — XCUITest UI + interaction simulation tests
- `IroniqWatchTests` — watchOS unit tests

### Frameworks
- **SwiftUI** — all UI, both targets
- **SwiftData** — local persistence (replaces CoreData)
- **HealthKit** — HKWorkoutSession, heart rate, calories
- **WatchConnectivity** — iPhone ↔ Watch sync
- **CloudKit / FileManager** — iCloud Drive session log export
- **StoreKit 2** — Ironiq Pro IAP
- **AppIntents** — Siri navigation commands
- **AVFoundation** — none (no sound)
- **Combine / async-await** — reactive state

### Data Flow
```
SwiftData (local) ←→ SessionEngine ←→ WatchConnectivity
                           ↓
                      HealthKit
                           ↓
                     iCloud Drive (on session end)
```

### Key Architectural Patterns
- **SessionEngine**: central state machine, single source of truth for active session
- **Repository pattern**: all SwiftData access through typed repositories
- **Actor isolation**: SessionEngine is a Swift actor to prevent data races
- **Dependency injection**: all services injected, never singleton except SessionEngine

---

## Data Models (SwiftData)

### Exercise
```swift
id, name, description, equipmentType, isSingleHand,
muscleGroups, iconName, isCustom, isSeeded
```

### Template
```swift
id, name, createdAt, exercises: [TemplateExercise]
```

### TemplateExercise
```swift
id, exercise, order, equipmentType, sets: [TemplateSet]
```

### TemplateSet
```swift
id, order, targetReps, targetWeight, targetDuration,
restDuration, noteLabel
```

### Session
```swift
id, template?, startedAt, endedAt, status (complete|incomplete|notPerformed),
plannedDuration, actualDuration, totalPauseDuration,
exercises: [SessionExercise], healthKitWorkoutId
```

### SessionExercise
```swift
id, exercise, order, executionOrder, status,
sets: [SessionSet], betweenExerciseRestStart, betweenExerciseRestEnd
```

### SessionSet
```swift
id, order, status (complete|incomplete|notPerformed),
reps, weight, setTimerStart, setTimerEnd,
restStart, restEnd, noteLabel, isUnrecorded
```

### PauseRecord
```swift
id, session, startedAt, endedAt, duration
```

---

## Session State Machine

States: `idle → templateSelected → active → paused → ending → ended`

Set lifecycle: `pending → inProgress → resting → awaitingInput → logged`

Timer types:
- `setTimer` — starts on set begin, freezes on Rest tap
- `restTimer` — starts on Rest tap, target vs actual tracked separately
- `betweenExerciseTimer` — passive stopwatch if no target defined
- `sessionTimer` — full elapsed, pauses with session
- `sessionMaxTimer` — hard 3-hour cutoff

---

## Exercise Seed Data

80 exercises minimum. Each has:
- Canonical name
- 20–30 word description
- Default equipment type
- `isSingleHand` flag
- Primary muscle group(s)
- Noun Project icon name (SVG filename)

Seed data lives in `IroniqExercises.json` in the app bundle.
Icons live in `Assets.xcassets/ExerciseIcons/`.

Include at minimum:
Deadlift, Romanian Deadlift, Sumo Deadlift, Squat, Front Squat, Goblet Squat,
Leg Press, Leg Extension, Leg Curl, Calf Raise, Lunge, Bulgarian Split Squat,
Flat Bench Press, Incline Bench Press, Decline Bench Press, Dumbbell Fly,
Cable Fly, Push Up, Dip, Overhead Press, Arnold Press, Lateral Raise,
Front Raise, Face Pull, Rear Delt Fly, Pull Up, Chin Up, Lat Pulldown,
Seated Row, Bent Over Row, Single-Arm Dumbbell Row, T-Bar Row, Shrug,
Barbell Curl, Dumbbell Curl, Hammer Curl, Preacher Curl, Cable Curl,
Tricep Pushdown, Skull Crusher, Overhead Tricep Extension, Tricep Dip,
Close Grip Bench Press, Plank, Side Plank, Crunch, Sit Up, Leg Raise,
Russian Twist, Cable Crunch, Ab Wheel Rollout, Hip Thrust, Glute Bridge,
Good Morning, Hyperextension, Farmer Carry, Suitcase Carry, Battle Ropes,
Box Jump, Burpee, Mountain Climber, Kettlebell Swing, Turkish Get Up,
Clean, Power Clean, Snatch, Hang Clean, Push Press, Thruster,
Wrist Curl, Reverse Curl, Zottman Curl, Cable Lateral Raise,
Machine Chest Press, Machine Shoulder Press, Machine Row, Pec Deck,
Smith Machine Squat, Hack Squat, Step Up, Nordic Curl

---

## Color Constants

```swift
// In Color+Ironiq.swift
static let ironiqOrange = Color(hex: "E8680A")
static let ironiqGreen  = Color(hex: "2D7D4A")
static let ironiqDark   = Color(hex: "1A1A1A")
static let ironiqRed    = Color(hex: "E53E3E")  // heart rate only
```

---

## Ironiq Pro — StoreKit

Product ID: `com.ir0niq.app.pro`

Gated features:
- Unlimited templates (free: 7)
- Full history (free: 90 days)
- Analytics + charts
- PR tracking
- Export (CSV + PDF)
- Custom exercise icons

---

## Siri — AppIntents

Supported intents only:
- `NextSetIntent`
- `PreviousSetIntent`
- `SkipSetIntent`
- `PauseSessionIntent`
- `ResumeSessionIntent`
- `EndSessionIntent`

No query intents. No reps/weight logging via Siri.

---

## iCloud Drive

Path: `iCloud Drive / Ironiq / Sessions / YYYY / MM /`
Filename: `ironiq_YYYYMMDD_HHMMSS_[template-slug].json.gz`
Format: JSON, gzipped
Estimated size: 1–5 KB per file

Write only on session end (complete or incomplete).
Never overwrite an existing file.

---

## Fastlane

Lanes to implement:
- `fastlane test` — run all tests on simulator
- `fastlane build` — archive release build
- `fastlane beta` — build + upload to TestFlight
- `fastlane release` — build + submit to App Store

Simulator for tests: latest available iOS 17+ iPhone simulator.

---

## Build Phases (Execution Order)

Codex executes these in strict order. Never advance to next phase until all tests in current phase pass.

### Phase 0 — Environment Check
Verify Xcode, simulators, signing identity, fastlane. Generate `.env.template`. Fail fast with clear error if anything is missing.

### Phase 1 — Foundation
- Xcode project scaffold, both targets, all schemes
- SwiftData models (all entities above)
- Repository layer
- SessionEngine state machine (no UI)
- Timer system
- Seed data loader (IroniqExercises.json)
- **Tests:** All model tests, state machine transitions, timer accuracy, seed data integrity

### Phase 2 — Core Session Logic
- Full set lifecycle implementation
- All forgot/edge case handling (see spec section 10)
- HealthKit integration (HKWorkoutSession)
- WatchConnectivity sync layer
- iCloud Drive export
- **Tests:** All session flows, every edge case scenario, HealthKit mock, connectivity mock, export format validation

### Phase 3 — iPhone UI
- All screens: onboarding, home, template list, template detail, template editor, active session, session summary, history (list + calendar), settings
- Navigation structure (tab bar)
- Active session: set/rest/pause states, Rest button, End Session (with confirmation)
- Review Before Saving screen
- **Tests:** UI tests for every screen, navigation flows, button states, interaction simulations including forgot scenarios

### Phase 4 — Watch UI
- Watch home, template scroll, active session faces (set/rest/input/pause)
- Set timer large center, rest countdown, heart rate display (red outline)
- Reps/weight input (dual Crown scroll)
- Rest button (persistent), End Session (distinct, confirm required)
- Music controls (swipe right)
- 5-second haptic countdown
- On-time celebration (green ring + checkmark flash)
- Watch complication
- **Tests:** Watch UI tests, haptic trigger tests, complication rendering

### Phase 5 — Integrations
- Siri AppIntents (6 navigation commands)
- StoreKit 2 IAP (Ironiq Pro)
- Feature gating
- **Tests:** Intent handling, purchase flow mock, feature gate enforcement

### Phase 6 — Polish + Regression
- Dark/light theme
- Imperial/metric unit switching throughout
- Accessibility (Dynamic Type, VoiceOver labels)
- Full regression test suite
- Performance tests (launch time, session start time)

### Phase 7 — Distribution
- Fastlane Appfile + Fastfile
- App icon set (1024x1024 base, all required sizes)
- Launch screen
- App Store metadata (description, keywords, screenshots spec)
- `fastlane beta` — TestFlight upload

---

## Testing Standards

Every phase must include:

1. **Unit tests** — all business logic, state transitions, data model operations
2. **Integration tests** — cross-layer flows (engine → repository → SwiftData)
3. **UI tests (XCUITest)** — every screen reachable, every primary action
4. **Interaction simulations** — scripted user journeys including:
   - Complete happy-path workout session
   - Forgot to tap Rest (nudge fires at 2× rest time)
   - Forgot to log reps (enforcement at exercise end)
   - Session abandoned mid-way (incomplete save)
   - Late start scenario
   - Unplanned exercise added mid-session
   - Pause during active set
   - Pause during rest
   - Session ends at 3-hour max timer
   - Ad-hoc session saved as template
   - Ironiq Pro purchase + feature unlock

Test target: **100% of business logic covered. 0 skipped tests.**
All tests must pass before phase is marked complete.
Use `XCTExpectation` and async test patterns throughout.
Mock HealthKit, WatchConnectivity, StoreKit, and iCloud in tests — never hit real services.

---

## File Structure

```
Ironiq/
├── .env                          ← never commit
├── .env.template                 ← commit this
├── .gitignore
├── AGENTS.md                     ← this file
├── README.md
├── Ironiq.xcodeproj/
├── Fastlane/
│   ├── Appfile
│   ├── Fastfile
│   └── Matchfile
├── Ironiq/                        ← iOS app
│   ├── App/
│   │   ├── IroniqApp.swift
│   │   └── AppState.swift
│   ├── Models/
│   ├── Engine/
│   │   ├── SessionEngine.swift
│   │   └── TimerSystem.swift
│   ├── Repositories/
│   ├── Services/
│   │   ├── HealthKitService.swift
│   │   ├── iCloudService.swift
│   │   ├── WatchSyncService.swift
│   │   └── StoreKitService.swift
│   ├── Intents/
│   ├── UI/
│   │   ├── Onboarding/
│   │   ├── Home/
│   │   ├── Templates/
│   │   ├── Session/
│   │   ├── History/
│   │   ├── Settings/
│   │   └── Components/
│   ├── Resources/
│   │   ├── IroniqExercises.json
│   │   └── Assets.xcassets/
│   └── Extensions/
│       └── Color+Ironiq.swift
├── IroniqWatch/                   ← watchOS app
│   ├── App/
│   ├── UI/
│   │   ├── Home/
│   │   ├── Session/
│   │   │   ├── SetFaceView.swift
│   │   │   ├── RestFaceView.swift
│   │   │   ├── InputFaceView.swift
│   │   │   └── PausedFaceView.swift
│   │   └── Complication/
│   └── Extensions/
├── IroniqTests/
├── IroniqUITests/
└── IroniqWatchTests/
```

---

## Rules for Codex

1. Never advance phases out of order
2. Never skip or stub tests — all must pass
3. Never read, print, or log `.env` values
4. Never commit sensitive data
5. Always use async/await over completion handlers
6. Always use SwiftData over CoreData
7. Always use SwiftUI over UIKit
8. Always handle errors explicitly — no `try!` or `force unwrap` in production code
9. Use `#Preview` macros for all SwiftUI views
10. Every public function has a doc comment
11. When a phase fails, diagnose and fix before proceeding — never work around a failing test
12. After each phase: run `fastlane test`, confirm all green, print summary
