# Ironiq — iOS + watchOS Gym Tracker
## Claude Code Project File

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
Claude Code must never read, print, log, or transmit `.env` contents.
`.env` is in `.gitignore` — never commit it.

---

## .env Schema

Claude Code must generate a `.env.template` (no real values) with these keys:

```
APPLE_ID=
TEAM_ID=
APP_STORE_CONNECT_API_KEY_ID=
APP_STORE_CONNECT_API_ISSUER_ID=
APP_STORE_CONNECT_API_KEY_PATH=
MATCH_PASSWORD=
```

The human fills in `.env` manually. Claude Code reads keys via fastlane's dotenv integration — never echo them.

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
- **Google Drive** — session log sync alongside iCloud Drive
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

### UserPreferences
```swift
unitSystem: UnitSystem (.imperial | .metric),  // default: .imperial — already exists in AppState
restReminderSeconds: Int,                       // default: 120, range: 30–300 — already exists in AppState
sessionsPerWeekTarget: Int                      // default: 5, range: 1–14 — NEW
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

Claude Code executes these in strict order. Never advance to next phase until all tests in current phase pass.

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
- Navigation: 3 tabs — **Analytics | Start | History** (text only, no icons)
- Start tab has two sub-tabs: **Workout** (default) and **Templates**
  - Workout sub-tab: Quick Start row pinned at top (subtle orange left border), then saved templates; template row tap = inline expansion; no edit/delete here
  - Templates sub-tab: list with section-header-style title; New Template button distinct from rows; right swipe = Edit, left swipe = Delete; no Start Workout from this tab
- Settings accessible only via profile icon top-right — not a tab
- Analytics tab: 2×2 metric grid (Consistency, Total Weight, Muscle Balance, Max Weight); each box tappable for expanded chart view
- All screens: onboarding (Sign In → Permissions → Preferences → Home), template detail, template editor, active session, session summary, history (list + calendar)
- Active session: set/rest/pause states, Rest button, End Session (with confirmation)
- Review Before Saving screen
- **Tests:** UI tests for every screen, navigation flows, sub-tab switching, Quick Start launches blank session, template Start launches correct template, no Pro gating logic anywhere

### Phase 4 — Watch UI
- Watch home, template scroll, active session faces (set/rest/input/pause)
- Set timer large center, rest countdown, heart rate display (red outline)
- Reps/weight input (dual Crown scroll)
- Rest button (persistent), End Session (distinct, confirm required)
- Swipe navigation: active workout is center/default; swipe right → Pause screen; swipe left → Music controls
- **Pause screen:** large "PAUSED" text, frozen elapsed time, current exercise + set X/Y, Resume button — nothing else
- **Music controls (re-implementation required):** Previous implementation was removed because it failed — watch read `MPNowPlayingInfoCenter.default()` which only reflects the watch app's own audio session, not the iPhone's active player; phone also had no handler for the WCSession media action messages. Correct approach: phone polls its own `MPNowPlayingInfoCenter` and pushes Now Playing state (title, artist) to watch via WCSession; watch displays it and sends transport commands ("mediaPrev", "mediaPlayPause", "mediaNext") back to phone; phone handles commands using `MPRemoteCommandCenter` + `UIApplication.beginReceivingRemoteControlEvents()`. Do not re-use the old WCSession-only relay without the phone-side NowPlaying polling and command handler.
- Watch storage full: persistent warning banner on home and active session; block new sessions until sync clears storage
- 5-second haptic countdown
- On-time celebration (green ring + checkmark flash)
- Watch complication
- **Tests:** Watch UI tests, swipe navigation, pause screen content, music controls render, haptic trigger tests, complication rendering

### Phase 5 — Integrations
- Siri AppIntents (6 navigation commands)
- Google Drive sync (auth token in Keychain; silent launch sync; same robustness as iCloud)
- **Tests:** Intent handling, Google Drive auth + sync mock

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
   - Template deleted with sessions → archived, sessions remain in History as "Archived"
   - Export CSV: verify all columns, all sessions including archived templates
   - Watch phone-disconnect: watch holds session locally, syncs on reconnect
   - Onboarding preferences: range validation blocks proceed, field clears on tap, defaults pre-populated

Test target: **100% of business logic covered. 0 skipped tests.**
All tests must pass before phase is marked complete.
Use `XCTExpectation` and async test patterns throughout.
Mock HealthKit, WatchConnectivity, iCloud, and Google Drive in tests — never hit real services.

---

## File Structure

```
Ironiq/
├── .env                          ← never commit
├── .env.template                 ← commit this
├── .gitignore
├── CLAUDE.md                     ← this file
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
│   │   ├── GoogleDriveService.swift
│   │   └── WatchSyncService.swift
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

## Rules for Claude Code

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
13. The "Continue as Demo" button must be preserved in all builds — required for App Store reviewer access
14. All features are free — never add feature gating, paywalls, or upgrade prompts
