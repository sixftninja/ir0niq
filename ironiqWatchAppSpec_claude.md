# Ironiq Watch App — Specification

## Purpose

Keep the user in their workout without picking up the phone. Nudge at the right moment, let them log in seconds, stay out of the way otherwise.

The watch is a workout remote, not a smaller phone app.

---

## What the Watch Has / Does Not Have

**Has:** workout monitoring dashboard, set logging, rest timing, haptics, music controls, live heart rate, complication.

**Does not have:** starting new workouts, template creation or editing, exercise library, adding exercises mid-session, history, settings, Pro upgrade, profile. Unit system mirrors the phone via WatchConnectivity — no unit editing on the watch.

Starting a new workout is phone-only. The watch detects an active session on the phone and mirrors it as a monitoring dashboard.

---

## Distribution

The watch app is embedded inside the iOS `.ipa`. No separate archive or upload step. The existing `fastlane beta` lane includes the watch app automatically as long as `IroniqWatch` is a dependency of the `Ironiq` scheme. When TestFlight installs the iOS build on the phone, the watch app installs on the paired Apple Watch SE 3.

---

## HKWorkoutSession Ownership

The watch owns the live `HKWorkoutSession` for heart rate accuracy. The phone owns Ironiq session state and persistence. The watch sends heart rate samples to the phone for HealthKit writing. No duplicate workout records.

---

## Global Navigation

`TabView` with `PageTabViewStyle`:

- Page 0: Ironiq main content
- Page 1: Music Controls

The app always opens to page 0. Swiping left from anywhere reaches music. Logging screens use push navigation, not horizontal swipe, to avoid conflict with the global page gesture.

---

## Screens

### 1. Idle

Shown when no workout is active on the phone.

- Ironiq icon, centered
- `Start a workout on your iPhone` — single line below
- No buttons, no navigation

The watch detects when a session becomes active on the phone and transitions automatically to the workout dashboard.

If the phone is unreachable: replace the message with `Open Ironiq on iPhone`.

### 2. Workout Dashboard (Active Set Face)

Shown when a session is active. Designed for a single glance. No exercise name, no set counter — space is limited and focus is critical.

Content:

- Target reps (or target duration) — large, center — e.g. `10 reps` or `45 sec`
- Target weight — below, with unit — e.g. `60 kg` or `132 lb`
- Heart rate badge when available — red, bottom corner
- `Finish Set` button — orange, full-width, bottom

There is no `Begin` button. Sets do not need to be manually started.

If the user is currently resting, a small rest countdown shows above the `Finish Set` button so they know where they are without navigating away.

### 3. Log Screen — Reps or Duration (Step 1 of 2)

Pushes when user taps `Finish Set`.

Content:

- Target reference line at top — small, e.g. `Target: 10 reps`
- Large centered value — monospaced bold — current entry
- Digital Crown scrolls the value. Reps: 0–100 by 1. Duration: 0–600 seconds by 5.
- Haptic tick on each Crown step
- Pre-filled with target as default
- Logging mode (reps vs duration) comes from the phone — no toggle shown unless the phone sends an ambiguous type
- Page indicator dots at bottom — 2 dots, step 1 active — weight is implied by the second dot
- `Next` button — advances to weight screen

### 4. Log Screen — Weight (Step 2 of 2)

Content:

- Target reference line at top — small, e.g. `Target: 60 kg`
- Large centered value — monospaced bold, one decimal place
- Unit label adjacent to value — `kg` or `lb`
- Digital Crown scrolls: 0–300 kg by 0.5, or 0–660 lb by 1
- When value is zero: shows `Bodyweight` instead of 0
- Pre-filled with target weight as default
- Page indicator dots — step 2 active
- `Log Set` button — green, full-width — submits both steps and returns to the dashboard

### 5. Rest Face

Shown after a set is logged and rest is active.

Content:

- `REST` — small caps, top
- Large countdown timer — white, center. Counts up in elapsed mode when no target exists.
- When overtime: timer turns red, counts up with `+` prefix
- Next set target preview — small, below timer — e.g. `Next: 10 reps · 60 kg`
- `Next Set` button — user can skip rest at any time

Overtime haptic fires once at the crossover moment.

### 6. Paused Face

- Pause icon + `Paused` label
- Elapsed workout time
- `Resume` button — orange, full-width
- Secondary `End` action below

### 7. End Session Confirm

Triggered only by an explicit `End` action — never by Digital Crown press.

- `End workout?`
- `End` — red, destructive
- `Cancel`

No accidental one-tap end path.

### 8. End Summary

Shown after end is confirmed.

- Duration
- Sets logged
- Volume
- Peak heart rate when available
- `Save` and `Discard` buttons

Intentionally compact. The phone is the right place for the richer completion screen.

### 9. Music Controls (Page 1, globally)

Reached by swiping left from anywhere.

- Current track name and artist from `MPNowPlayingInfoCenter`
- Previous / Play-Pause / Next
- `MPRemoteCommandCenter` handlers registered once at app init — not inside button handlers

---

## Haptics

| Trigger | Type |
|---|---|
| Workout becomes active on watch | `.start` |
| `Finish Set` tapped | `.click` |
| Each Digital Crown increment while logging | `.click` |
| Set logged successfully | `.success` |
| Last 5 seconds of rest countdown | `.click` — one per second |
| Rest reaches target | `.success` |
| Rest first goes overtime | `.failure` — once only |
| 120 seconds after set is ready with no logging | `.notification` — once only |
| Workout saved | `.success` |

---

## Complication

Two sizes:

- `accessoryCircular`: Ironiq icon when idle; elapsed session time when active
- `accessoryRectangular`: `Ironiq` when idle; current target reps/duration and weight when active

`WidgetCenter.current.reloadTimelines()` called on every state change received from the phone.

---

## Data Flow

### Watch Receives from Phone

- Engine state (idle / active / paused)
- Set status (pending / inProgress / resting / awaitingInput / logged)
- Logging type (reps / duration)
- Target reps
- Target duration
- Target weight
- Rest target duration
- Rest start date anchor
- Session start date anchor
- Unit system

### Watch Sends to Phone

- `finishSet`
- `logSet(reps: Int?, duration: TimeInterval?, weight: Double?)`
- `nextSet`
- `pause`
- `resume`
- `requestEndSession`
- `confirmEndSession`
- `saveSession`
- `discardSession`

No `startSession`. No `startNewSession`. No `beginSet`. No `tapRest`. No `startAdHocSession`.

### Watch Derives Locally

- Session elapsed timer from session start date anchor
- Rest countdown and overtime from rest anchor
- Haptic schedule from mirrored state
- Live heart rate from `HKWorkoutSession`

---

## Error and Offline States

- Phone unreachable → show `Open Ironiq on iPhone` on idle screen
- Phone reachable but no active session → show idle screen
- Phone rejects an action → revert UI to last confirmed mirrored state, do not show success
- Heart rate unavailable → hide badge silently
- Save/discard fails → show retry option

---

## What Needs to Change vs Current Code

| Item | Required change |
|---|---|
| `WatchHomeView` | Replace template list with simple idle message; add phone-unreachable state |
| `WatchSetFaceView` | Remove exercise name and set counter; show target reps/weight as primary content; rename action to `Finish Set`; remove `Begin` button |
| `WatchActiveSessionView` | Restructure TabView: main content page 0, music page 1 (swipe left = music) |
| `WatchRestFaceView` | Add overtime haptic at crossover; add next-set target preview |
| `WatchInputFaceView` | Remove exercise/set header; add target reference line; add page dots for 2-step flow; logging type from phone only |
| `WatchMusicControlsView` | Fix `MPRemoteCommandCenter` wiring — register at app init not in button handlers |
| `WatchSessionViewModel` | Remove all session-start logic; add 120s no-log reminder; add overtime haptic; remove `beginSet`, `tapRest`, `startAdHocSession` actions |
| Complication | Wire `WidgetCenter.current.reloadTimelines()` on state change; show target in rectangular size |

---

## Testing Requirements

- Phone unreachable → idle shows correct message
- Phone session becomes active → watch transitions to dashboard automatically
- `Finish Set` opens reps/duration logging
- Reps entry via Crown with haptic ticks
- Duration entry via Crown with haptic ticks
- Weight entry metric and imperial
- Bodyweight zero state
- Target values pre-fill both log screens
- Page dots show correct step
- Rest countdown from anchor
- Rest overtime haptic fires once only
- 120s no-log reminder fires once only
- Pause and resume
- End confirmation blocks accidental end
- Save and discard send correct messages
- Heart rate badge hidden when unavailable
- Complication updates on state change
