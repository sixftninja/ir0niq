# Ironiq Watch App — Final Specification

## Product Principle

The Ironiq Watch app is a fast workout companion, not a miniature iPhone app.

The phone is the full app. The watch is the fast subset used during training.

The watch should help the user:

- choose a workout template
- start the workout
- see the current set target
- finish or skip a set
- log reps/duration and weight quickly
- pause, resume, or end the workout
- receive set-logging nudges
- control music

The watch should avoid anything that feels like planning, editing, account management, or administration.

---

## Phone vs Watch Responsibility

### Phone App

The phone app is the superset.

The phone can do everything the watch can do, plus:

- create workout templates
- edit workout templates
- manage exercises
- add/remove/reorder exercises
- manage workout history
- manage user profile
- manage login providers
- manage unit system
- manage settings
- show rich workout summaries
- handle full persistence and sync

### Watch App

The watch app can:

- display workout template list
- start a selected workout
- display active workout/set state
- display live heart rate during active workouts
- finish set
- skip set
- log set
- pause workout
- resume workout
- end workout
- save or discard completed workout
- display reminder nudges
- display music controls

The watch app must not include:

- login
- profile
- settings
- unit switching
- template creation
- template editing
- exercise library browsing
- exercise adding/removal
- workout history
- Pro upgrade/payment screens

Unit system mirrors the phone.

---

## Important Product Change: No Rest Functionality

Ironiq no longer cares about rest tracking.

There should be no rest timer, rest screen, rest countdown, rest overtime, rest haptics, rest preview, or next-set-after-rest flow in the watch app.

Remove all rest-related watch functionality from prior specs.

After a set is logged, the watch should automatically return to the active workout screen for the next set.

---

## App Launch / Startup Flow

It is fully expected that the user may open Ironiq on the watch first, possibly from a watch-face complication.

Therefore, startup should show the workout template list, not an idle instruction screen.

### Template List Screen

Show workout templates immediately.

The list should be optimized for the watch screen:

- two templates visible at a time
- optional hint of a third item if natural in the list layout
- no exercise list
- no template editing
- no search
- no filters
- no settings

Each row should show only essential information.

Example:

```text
Push Day
8 exercises

Legs
6 exercises
```

Tapping a workout template should not immediately start the workout. It should open a start confirmation screen.

This prevents accidental starts.

---

## Start Workout Confirmation Screen

Shown after the user taps a workout template.

Content:

```text
Push Day

Start Workout
```

Optional secondary metadata may be shown if it fits cleanly:

```text
8 exercises
```

Do not show the full exercise list.

Primary action:

- `Start Workout`

After tapping `Start Workout`:

- workout starts
- watch transitions to active workout screen
- phone app receives/reflects the active workout state

---

## Active Workout Screen

This is the main screen during a workout.

It should be extremely focused.

Required content:

- active set number
- target reps or target duration
- live heart rate badge when available
- `Finish Set` button
- `Skip Set` button

Example for reps-based set:

```text
Set 3/4          ♥ 142

10 reps

Finish Set

Skip Set
```

Example for duration-based set:

```text
Set 2/3          ♥ 142

45 sec

Finish Set

Skip Set
```

### Heart Rate

Heart rate is a major watch advantage and should be visible during active workouts.

Show it as a small badge with a heart icon and the current number only. Do not write `bpm`.

Example:

```text
♥ 142
```

Preferred placement: top-right or another low-distraction corner of the active workout screen.

Heart rate should never dominate the set target. The user is lifting; the heart rate is context, not the main task.

If heart rate is unavailable, hide it silently. Do not show an error.

### Exercise Name and Workout Name

Objective priority:

1. set number
2. target reps/duration
3. `Finish Set`
4. `Skip Set`
5. exercise name
6. workout name

Workout name should not be shown on the active workout screen.

Once the workout has started, the workout name is low-value. The user needs to know what to do now, not the container they are inside.

Workout name may appear on:

- template list
- start confirmation screen
- end summary screen if space allows

Exercise name is useful, but space is tight.

If it fits cleanly, show exercise name as a small top label:

```text
Bench Press
Set 3/4

10 reps

Finish Set
Skip Set
```

If the screen feels crowded, drop the exercise name.

Set number is mandatory. Exercise name is optional. Workout name is not shown on the active workout screen.

---

## Active Workout Screen Actions

### Finish Set

Tapping `Finish Set` opens the log set screen.

No separate `Begin Set` action should exist.

A set begins when the user begins lifting. The app only needs to know when the set is complete.

### Skip Set

Tapping `Skip Set` skips the current set and advances to the next set.

If confirmation is needed for safety, keep it lightweight. But avoid making skipping feel bureaucratic.

---

## Log Set Screen

Logging must be intuitive, readable, and not crowded.

Use one screen, not a two-step flow.

The user should be able to log reps/duration and weight with one final button press.

### Reps-Based Log Screen

Example:

```text
Reps
10

Weight
60 kg

Done
```

### Duration-Based Log Screen

Example:

```text
Duration
45 sec

Weight
60 kg

Done
```

### Bodyweight Display

If weight is zero, show `Bodyweight` instead of `0 kg`.

Example:

```text
Reps
12

Weight
Bodyweight

Done
```

### Input Behavior

The screen has two editable fields:

- reps/duration
- weight

The Digital Crown edits the currently selected field.

Suggested behavior:

- tapping the reps/duration field selects it
- tapping the weight field selects it
- Crown changes selected value
- `Done` logs the set and returns to active workout screen

### Defaults

Values should be pre-filled from the target set:

- target reps pre-fill actual reps
- target duration pre-fills actual duration
- target weight pre-fills actual weight

Most sets match the plan. Do not force unnecessary entry.

### Reps / Duration Mode

Do not show a reps/duration toggle unless absolutely necessary.

The template/session state should already know whether the set is reps-based or duration-based.

The watch should show either `Reps` or `Duration`, not both.

A toggle consumes space and creates avoidable confusion.

---

## After Logging a Set

After the user taps `Done`:

- send logged set to phone
- update session state
- advance to next set
- return automatically to active workout screen

There is no rest screen.

---

## Workout Controls Screen

During an active workout, swiping left-to-right from the main workout area should reveal workout controls.

Workout controls screen contains:

- `Pause`
- `End`

Example:

```text
Workout

Pause

End
```

`End` should not immediately end the workout. It must open the end confirmation screen.

---

## Music Controls Screen

During workout, swiping right-to-left should reveal music controls.

Music controls screen contains:

- current track name if available
- artist if available
- previous
- play/pause
- next

The music screen should be reachable globally during workout.

Do not overload the same swipe direction for both workout controls and music.

Gesture model:

- left-to-right swipe: workout controls
- right-to-left swipe: music controls

---

## Paused State

If the user taps `Pause`, the user stays on the workout controls screen.

Paused controls screen:

```text
Paused

Resume

End
```

If the user manually swipes back to the active workout screen while paused, the active workout screen should show only:

```text
Set 3/4

Resume
```

Do not show `Finish Set` or `Skip Set` while paused.

The user must resume before continuing set actions.

---

## End Workout Confirmation

Ending must require confirmation.

There should be no accidental one-tap end path.

End confirmation screen:

```text
End workout?

End Workout

Cancel
```

`End Workout` is destructive and should be visually treated as such.

`Cancel` returns to the prior workout state.

---

## End Summary / Reward Screen

After ending a workout, show a compact rewarding summary.

Only show:

- duration
- volume

Example:

```text
Workout Complete

42 min
8,420 kg

Save
Discard
```

Keep this compact. The phone app is the right place for the richer completion screen.

### Save

Tapping `Save` sends save request to phone.

If successful:

- show success state briefly
- return to template list or idle/template state

### Discard

Tapping `Discard` sends discard request to phone.

If confirmation is desired, keep it minimal.

### Save/Discard Failure

If save/discard fails, show retry option.

Example:

```text
Couldn’t save

Retry
```

---

## Reminder Nudges to Log a Set

The phone app already has a set-logging reminder, defaulting to 120 seconds.

The watch should mirror reminder events from the phone instead of running a separate independent reminder timer, unless implementation constraints require local fallback.

Preferred behavior:

- phone owns reminder timing
- watch receives reminder event
- watch gives haptic nudge
- watch shows log prompt

Reminder prompt:

```text
Log set?

Log

Skip
```

Actions:

- `Log` opens log set screen
- `Skip` dismisses prompt and returns to active workout screen

Avoid duplicate reminders from phone and watch.

Do not let both devices independently nag the user for the same set.

---

## Haptics

Use haptics sparingly.

Required haptics:

| Trigger | Haptic |
|---|---|
| Workout started | start/success-style haptic |
| Finish Set tapped | light click |
| Digital Crown value change | light click |
| Set logged successfully | success |
| Reminder to log set | notification |
| Workout paused | light click |
| Workout resumed | success/light confirmation |
| Workout ended | success/strong completion |
| Workout saved | success |

No rest haptics.

---

## Complication

The watch app may be launched from a complication.

Complication behavior should support quick re-entry.

Suggested states:

### Idle / No Active Workout

Show Ironiq icon or `Ironiq`.

Tapping opens the watch app to the workout template list.

### Active Workout

Show compact active workout state.

Suggested circular complication:

- current set number or simple active indicator

Suggested rectangular complication:

```text
Set 3/4 · 10 reps
```

If space allows:

```text
Set 3/4 · 10 reps · 60 kg
```

On state changes from phone/watch, complication timelines should update.

---

## Phone and Watch Sync

The phone and watch should behave like two views of one workout.

### Watch Receives from Phone

- workout template list
- selected/available workout metadata
- active workout state
- live heart rate availability/status if synced from phone, while direct watch measurement remains preferred during workout
- paused state
- active exercise/set position
- target reps
- target duration
- target weight
- unit system
- reminder events
- save/discard result
- session completion state

### Watch Sends to Phone

- select/start workout template
- finish set
- log set
- skip set
- pause workout
- resume workout
- request end workout
- confirm end workout
- save workout
- discard workout

### Watch Should Not Send

- create template
- edit template
- add exercise
- remove exercise
- change units
- change settings
- login/logout
- profile changes

---

## Offline / Unreachable Behavior

If the phone is unreachable at app launch, show a useful message.

Example:

```text
Open Ironiq on iPhone
```

If cached workout templates are available and safe to show, they may be shown, but starting/sync behavior must be reliable.

Do not pretend actions succeeded if the phone did not confirm them.

If phone rejects an action:

- revert UI to last confirmed state
- do not show success haptic
- avoid noisy technical errors

---

## Testing Requirements

Test these flows:

- app launches to workout template list
- template list shows approximately two items at a time
- tapping template opens start confirmation screen
- tapping Start Workout starts workout
- phone reflects workout started from watch
- phone-started workout appears correctly on watch
- active screen shows set number and reps/duration target
- active screen shows heart icon plus number when heart rate is available
- active screen hides heart rate silently when unavailable
- active screen shows Finish Set and Skip Set
- exercise name appears only if layout remains clean
- workout name is not shown on active workout screen
- Finish Set opens one-screen log UI
- reps logging works via Digital Crown
- duration logging works via Digital Crown
- weight logging works via Digital Crown
- selected field behavior is obvious
- zero weight displays Bodyweight
- Done logs set and returns to active screen
- Skip Set advances to next set
- swipe left-to-right opens workout controls
- swipe right-to-left opens music controls
- Pause keeps user on controls screen
- paused active screen shows only set number and Resume
- Resume returns to normal active workout behavior
- End opens confirmation screen
- Cancel from end confirmation returns to workout
- confirmed End opens reward summary
- reward summary shows only duration and volume
- Save sends save request to phone
- Discard sends discard request to phone
- save failure shows retry option
- phone reminder event appears on watch
- reminder prompt opens log screen when user taps Log
- reminder prompt dismisses when user taps Skip
- no duplicate phone/watch reminder nagging
- complication opens app to useful state
- complication updates during active workout
- phone unreachable state is clear
- rejected actions revert to last confirmed state

---

## Final Product Rule

The watch should never make the user manage the app.

It should only ask for fast workout decisions:

- choose workout
- start
- finish set
- skip set
- log
- pause
- resume
- end
- save/discard

Everything else belongs on the phone.
