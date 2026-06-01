# Ironiq Watch App — Specification v2

## Purpose

Keep the user in the workout without making them pick up the phone. The watch should make it extremely easy to finish a set, log reps or duration, log weight, see rest timing, and receive haptic nudges at the right moment.

The watch is a fast workout remote, not a smaller version of the phone app.

---

## Product Principles

- The user understands `finish set`, not `start rest`.
- Sets are not manually started.
- Rest is a consequence of finishing/logging a set.
- The phone remains the source of truth for templates, history, settings, and persistence.
- The watch can derive live timers locally from phone-provided date anchors.
- Haptics should reduce forgetting, not annoy the user.

---

## What the Watch Has / Does Not Have

**Has:** session start, session resume, current set display, set logging, rest timer display, haptics, template selection, New workout start, pause/resume, end session, short end summary, music controls, complication, live heart rate when available.

**Does not have:** template creation or editing, exercise library browsing, history, analytics, settings, Pro upgrade, profile, unit editing, Apple login, iCloud management.

The unit system mirrors the phone through WatchConnectivity.

---

## Distribution

The watch app is embedded inside the iOS `.ipa`. There is no separate archive or upload step. The existing `fastlane beta` lane includes the watch app automatically as long as `IroniqWatch` is a dependency of the `Ironiq` scheme.

When TestFlight installs the iOS build on the phone, the watch app installs on the paired Apple Watch if automatic watch app installation is enabled.

---

## Source of Truth

The iPhone `SessionEngine` is the source of truth.

The watch sends user actions to the phone:

- start workout
- finish set
- log set
- pause
- resume
- end
- save
- discard

The phone mirrors session state back to the watch after every accepted action.

If the phone is unreachable, the watch must show a clear unavailable state instead of pretending an action succeeded.

---

## Global Navigation

The watch app uses a two-page `TabView` with `PageTabViewStyle`:

- Page 0: Music Controls
- Page 1: Ironiq main content

The app opens to Page 1.

Swiping right from main content reaches music. Logging screens should not rely on horizontal swipe as the primary action because that competes with global page navigation.

---

## Screens

### 1. Idle — Start

Shown when no workout is active.

Content:

- `New` row/button at top
- List of saved templates below
- Each template row shows template name and exercise count
- Tapping `New` sends `startNewSession`
- Tapping a template sends `startSession(templateId:)`

No `Ad-hoc` wording appears anywhere.

If templates are not yet loaded, show a quiet loading state. If the phone cannot be reached, show `Open Ironiq on iPhone`.

### 2. Active Set Face

Shown when a set is available to perform.

Content:

- Exercise name
- `Set X / Y` as the primary visual element
- Target reps or target duration
- Target weight, if any
- Heart rate badge when available
- Rest timer mini-display if currently resting
- Main button: `Finish Set`

The screen should feel glanceable. The user should be able to identify the set number instantly.

There is no `Begin` button.

### 3. Finish Set / Log Screen — Reps or Duration

Opens when the user taps `Finish Set`.

Content:

- Exercise name
- `Set X / Y`
- Active logging mode: `Reps` or `Duration`
- Large centered value
- Digital Crown adjusts the value
- Haptic tick on each Crown increment
- `Next` button

Rules:

- Reps range: 0-100 by 1
- Duration range: 0-600 seconds by 5
- Initial value uses the target as placeholder/default
- If the user does not change the value, the default is accepted
- The user can cancel by navigating back, which returns to the active set without logging

The logging mode is determined by the exercise/set coming from the phone. The watch does not make the user choose reps vs duration unless the phone state allows that.

### 4. Finish Set / Log Screen — Weight

Second step after reps/duration.

Content:

- Exercise name
- `Set X / Y`
- Weight label with unit
- Large centered value
- Digital Crown adjusts the value
- `Bodyweight` appears when value is zero
- Main button: `Log Set`

Rules:

- Metric: 0-300 kg by 0.5
- Imperial: 0-660 lb by 1
- Initial value uses the target/default as placeholder/default
- Submitted value is sent with reps or duration

After successful logging, the phone starts/updates rest timing and mirrors the next state back to the watch.

### 5. Rest Face

Shown after a set has been logged and rest is active.

Content:

- `REST`
- Large timer
- Target rest
- Overtime indication
- Next set preview if available
- Main button: `Next Set`

Timer behavior:

- Counts down while under target
- At target, triggers haptic
- Past target, turns orange/red and counts overtime with a `+`
- Overtime haptic fires once

The user can move to the next set at any time. Timers are targets, not enforced locks.

### 6. Paused Face

Content:

- Pause icon
- `Paused`
- Elapsed workout time
- `Resume` button
- Secondary `End` action

### 7. End Session Confirm

Triggered from an explicit `End` action, not by pressing the Digital Crown.

Content:

- `End workout?`
- `End` destructive button
- `Cancel`

There must be no accidental one-tap end path.

### 8. End Summary

Shown after end is confirmed.

Content:

- Duration
- Exercises
- Volume
- Peak heart rate, when available
- `Save`
- `Discard`

This is intentionally smaller than the phone reward screen. The phone remains the best place for richer completion animation and edit-before-save.

### 9. Music Controls

Global Page 0.

Content:

- Current track name
- Artist
- Previous
- Play/Pause
- Next

`MPRemoteCommandCenter` handlers are registered once at app initialization. Buttons only trigger commands.

---

## Haptics

| Trigger | Haptic type |
|---|---|
| Workout starts | `.start` |
| User taps Finish Set | `.click` |
| Each Digital Crown increment while logging | `.click` |
| Set logged successfully | `.success` |
| Last 5 seconds before rest target | `.click`, one per second |
| Rest reaches target | `.success` |
| Rest first goes overtime | `.failure`, once only |
| 120 seconds after a set appears without logging | `.notification`, once only |
| Workout saved | `.success` |

The 120-second reminder is the free-version default. Future intelligent set-time reminders can replace this after enough per-exercise data exists.

---

## Heart Rate

The watch owns live heart rate collection during an active workout.

Requirements:

- Show current heart rate during active session screens
- Track peak heart rate for end summary
- Send heart rate samples or summary back to the phone
- Avoid creating duplicate HealthKit workout records between phone and watch

Open implementation question:

- Decide whether the watch or phone owns the canonical `HKWorkoutSession`. The likely answer is watch-owned workout session for heart rate accuracy, with the phone owning Ironiq session state.

---

## Complication

Two sizes supported:

- `accessoryCircular`: Ironiq icon when idle; elapsed session time when active
- `accessoryRectangular`: `Ironiq` when idle; exercise name + set number when active

Complication updates should be requested when session state changes. Do not assume second-by-second live complication updates are reliable.

---

## Data Flow

### Watch Receives from Phone

- Engine state
- Active session ID
- Workout name
- Exercise name
- Exercise index and total exercises
- Set number and total sets
- Set status
- Logging type: reps or duration
- Target reps
- Target duration
- Target weight
- Rest target duration
- Rest start date
- Rest target end date
- Session start date
- Unit system
- Template list with exercise counts
- Phone reachability/session availability

### Watch Sends to Phone

- `startSession(templateId: UUID)`
- `startNewSession`
- `finishSet`
- `logSet(reps: Int?, duration: TimeInterval?, weight: Double?)`
- `nextSet`
- `pause`
- `resume`
- `requestEndSession`
- `confirmEndSession`
- `saveSession`
- `discardSession`

Do not send `beginSet`.

Do not send `startAdHocSession`.

### Watch Derives Locally

- Session elapsed timer from session start date
- Rest countdown/overtime from rest anchors
- Haptic schedule from mirrored state
- Current heart rate from HealthKit

---

## Error and Offline States

The watch must handle these cases clearly:

- Phone unreachable
- Phone reachable but no active Ironiq session
- Phone rejects an action because session state changed
- Template list not available yet
- HealthKit heart rate unavailable
- Save/discard fails

The watch should never show a successful state until the phone accepts the action or sends the matching mirrored state.

---

## What Needs to Change vs Current Code

| Item | Required change |
|---|---|
| Watch idle screen | Replace static screen with New + template list |
| Existing `Begin` flow | Remove from watch UX |
| Existing `Rest` primary action | Replace with `Finish Set` mental model |
| Input flow | Use two-step Crown logging: reps/duration, then weight |
| Horizontal log swipe | Avoid as primary navigation because music is global swipe page |
| Session action names | Use `startNewSession`, `finishSet`, `logSet`; remove `startAdHocSession` and `beginSet` |
| End session | Use explicit End action and confirmation, not Digital Crown press |
| Haptics | Add reminder, rest target, overtime, and logging success haptics |
| Heart rate | Define watch-owned live collection and phone sync |
| Complication | Update on state changes, with realistic expectations for live timing |
| Offline handling | Add explicit unreachable/rejected-action states |

---

## Testing Requirements

Tests must cover:

- Start new workout from watch
- Start template workout from watch
- Phone unreachable on start
- Finish set opens logging
- Reps logging through Crown values
- Duration logging through Crown values
- Weight logging with metric and imperial units
- Bodyweight zero state
- Rest countdown
- Rest overtime haptic fires once
- 120-second forgot-to-log reminder fires once
- Pause/resume
- End confirmation prevents accidental end
- Save and discard messages
- Template list sync
- Mirrored state recovery after phone-side session changes
- Heart rate unavailable state

