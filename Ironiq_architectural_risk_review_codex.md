# Ironiq Architectural Risk Review Codex

## Scope

This document is a targeted, critical review of the current Ironiq codebase after the recent Apple/Google login, cloud sync, SwiftData startup recovery, and template editing changes. It is written to help a second reviewer perform a deeper independent audit, especially around crash risk, data safety, brittle architecture, security, and test gaps.

It is not a replacement for a full line-by-line audit. It focuses on the code paths most connected to the recent TestFlight startup crashes, sync onboarding work, session flow regressions, and template editing bugs.

## Executive Summary

Ironiq has several strong architectural ideas: a central `SessionEngine` actor, SwiftData repositories, clear user-owned storage goals, a growing test suite, and a product direction that treats workout history as the core value. Those are the right foundations.

The current implementation is still brittle in a few high-risk places. The biggest risk is not the UI. It is data lifecycle: startup recovery can delete the local SwiftData store, cloud sync can appear complete without proving durable export, and export failures can be swallowed. For an app whose main promise is trustworthy workout history, that needs to be hardened before App Store release.

The recent set-deletion crash appears fixed in build 36, and test coverage was added around the specific regression. However, the episode exposed a broader pattern: nested mutable SwiftUI editor state can produce incorrect behavior unless every mutation is id-based and tested through the user-visible result.

## Current Product Feedback, Not Architecture Review

The new horizontal `+ Set` button is much better.

Removing exercises now works, but the permanent `Remove Exercise` button in the template exercise editor should be removed. The desired product behavior is: deleting all sets deletes the exercise. Users should not need a separate remove-exercise action in that editing flow.

Recommended implementation later:

- Remove the always-visible `Remove Exercise` button from the expanded exercise editor.
- Allow deleting the final set to remove the exercise row.
- Keep the current id-based mutation approach from build 36.
- Add a UI regression test: create template, add exercise with multiple sets, delete sets one by one, assert the exercise disappears only when the final set is deleted.
- Add a duplicate prevention test: once an exercise exists in a template, it should not be selectable again from the picker.

## Crash Timeline Around Sync/Login Work

Recent commits suggest the unstable period began around cloud login and bundle/signing changes:

- `60d4ca0 Add Google Drive sync setup`
- `38c8e15 Fix sync login completion`
- `bc54d2c Bump build number to 29`
- `ebeb682 Guard SwiftData startup failures`
- `0353aa2 Prevent startup crash on SwiftData failure`
- `b69d584 Fix SwiftData startup recovery`
- `880ecfc Disable SwiftData CloudKit startup`
- `d0a24dd Fix template set editing regressions`

The TestFlight crash stack pointed at `IroniqApp.init()` and the SwiftData model container initialization path. The current code avoids a fatal startup crash by attempting normal store, rebuilt store, then in-memory store. That is better than crashing, but it is not yet a robust data strategy.

## High-Risk Findings

### 1. SwiftData Startup Recovery Can Destroy Local Data

Files:

- `Ironiq/App/IroniqApp.swift`
- `Ironiq/Services/ModelContainerFactory.swift`

`AppStartup.make()` now tries to recover from persistent store failure. The recovery path calls `makeRebuiltSharedContainer()`, which removes the SQLite store files and recreates the container.

This prevents launch crashes, but it creates a serious product risk: if the store fails because of a migration issue, CloudKit option mismatch, bundle transition, model mismatch, or transient corruption, the app may delete the local workout database.

Why this matters:

- Workout history is the product’s highest-value user data.
- Cloud sync/export is not yet proven to be complete for both providers.
- A user may lose local templates/history before export has succeeded.
- The failure screen asks the user to reinstall, but the code may already have attempted destructive recovery.

Recommended fix:

- Never delete the store as the first recovery strategy.
- Copy the broken store files to a timestamped diagnostic backup before any rebuild.
- Add explicit schema migration/version handling.
- If recovery is needed, launch into a limited recovery mode that lets the user export diagnostics or reset intentionally.
- Add tests that seed an old/corrupt/mismatched store and assert data is preserved or backed up.

### 2. Cloud Sync Gate Can Mark Setup Complete Too Early

Files:

- `Ironiq/App/ContentView.swift`
- `Ironiq/App/AppState.swift`
- `Ironiq/Services/iCloudService.swift`

The first-launch gate records sync completion in `UserDefaults` after folder preparation. This proves that setup reached a certain point, but it does not prove that future session/template exports are durable, retried, provider-specific, or recoverable.

Current state risks:

- `syncEnabled` can be true even if tokens are expired, revoked, missing, or Drive/iCloud is no longer available.
- A Google user can pass onboarding, but template/session export code still uses `iCloudService` in important places.
- If iCloud export fails after setup, the user may not know.
- Sync account metadata in `UserDefaults` can drift from actual Keychain/auth state.

Recommended fix:

- Replace boolean `syncEnabled` with a richer sync state: `notConfigured`, `configured`, `needsAttention`, `syncing`, `failed`, `offlineQueued`.
- Verify provider health on launch.
- Store every export as a local pending job first, then mark synced only after provider upload succeeds.
- Show a visible but calm warning if sync is not currently healthy.

### 3. Google Drive Provider Is Not Fully Integrated Into Export Flow

Files:

- `Ironiq/Services/iCloudService.swift`
- `Ironiq/ViewModels/TemplateViewModel.swift`
- `Ironiq/Engine/SessionEngine.swift`

Google OAuth and folder creation exist, but session/template export paths still appear iCloud-centered. `TemplateViewModel.exportTemplateIfNeeded` always calls `iCloudService.shared.exportTemplate`. `SessionEngine.confirmEnd` attempts `iCloudService.exportSession` and swallows failure.

This creates a mismatch with the product promise: users choose Apple/iCloud or Google/Drive, and their history/templates should live in that chosen drive.

Recommended fix:

- Introduce a `CloudStorageProvider` protocol with concrete `iCloudDriveStorageProvider` and `GoogleDriveStorageProvider` implementations.
- Route all exports through the selected provider.
- Persist upload queue records locally before upload.
- Add provider-specific integration tests with mocked Drive/iCloud clients.

### 4. Sync Failures Are Too Easy To Hide

Files:

- `Ironiq/Engine/SessionEngine.swift`
- `Ironiq/ViewModels/TemplateViewModel.swift`

`SessionEngine.confirmEnd` uses `try?` around iCloud export. Template export catches errors and shows a generic alert saying cloud sync will retry, but no durable retry queue is visible in the inspected path.

This is dangerous because the user may believe history is safely stored in their cloud drive when it is not.

Recommended fix:

- No silent `try?` for sync-critical work.
- Write export intent to a local sync queue first.
- Expose sync status in settings/profile.
- Retry with backoff.
- Include export status in history detail if a session is not yet synced.

### 5. Navigation State Is Fragile

File:

- `Ironiq/UI/Components/IroniqTabView.swift`

The app currently coordinates session UI with several boolean bindings, including `showWorkoutDashboard`, `showLogOnDashboardOpen`, `showSessionSummary`, and `showActiveExercisePicker`.

This is likely related to earlier bugs where the dashboard vanished, the start button did not become active, or flows returned to the wrong screen.

Recommended fix:

- Replace competing booleans with a single enum-based router, for example `AppRoute` plus `SessionPresentationState`.
- Make active workout presentation derive from session engine state where possible.
- Add UI tests for these flows: start template, minimize dashboard, add exercise, return through active start button, end workout, save/discard.

### 6. Session Repair Logic Lives Too High In The UI Layer

File:

- `Ironiq/ViewModels/SessionViewModel.swift`

`SessionViewModel` currently tries to repair engine state before starting sessions. It handles `templateSelected`, `ending`, `ended`, active/paused state, and uses some `try?` transitions.

This makes the UI view model a partial session coordinator. It can mask real engine bugs and create mismatches between UI state and engine state.

Recommended fix:

- Move start/restart/recover behavior into explicit session use cases or into `SessionEngine` APIs.
- Return typed results like `alreadyActive`, `recoveredEndedSession`, `blockedBecauseEnding`.
- Avoid `try?` in state repair paths.
- Add tests for every state from which `startTemplateSession` and `startAdHocSession` can be called.

### 7. Global `SessionEngine.current` Is Brittle

Files:

- `Ironiq/App/AppModel.swift`
- `Ironiq/Engine/SessionEngine.swift`
- `Ironiq/Intents/SessionIntents.swift`

The app stores a global mutable `SessionEngine.current` for AppIntents. This is convenient, but fragile for lifecycle, tests, extensions, and future watch/Siri work.

Recommended fix:

- Replace with a dedicated intent bridge or dependency provider.
- For intents that can run out-of-process, store command requests in App Group/shared state and let the app/session coordinator consume them safely.
- Tests should not depend on global engine mutation unless explicitly isolated.

### 8. Template Editor State Remains A High-Risk UI Area

File:

- `Ironiq/UI/Templates/TemplateEditorView.swift`

The build 36 fix improved set editing by using stable ids instead of stale indices. That is the right direction. The remaining risk is that this editor still holds nested mutable draft state and performs many inline mutations.

Known current product issue:

- The UI now includes a permanent `Remove Exercise` button that should not exist.
- Desired behavior is last-set deletion removes the exercise.

Recommended fix:

- Keep all nested mutations id-based.
- Extract editing operations into a small draft model or reducer with unit tests.
- UI should call operations like `removeSet(exerciseId:setId:)`, `duplicateLastSet(exerciseId:)`, `removeExerciseIfNoSets(exerciseId:)` instead of directly mutating arrays in multiple places.

### 9. iCloud Fallback Can Violate The Product Promise

File:

- `Ironiq/Services/iCloudService.swift`

The iCloud export path can fall back to local Documents if the ubiquity container is unavailable. That may be useful for development, but in production it conflicts with the requirement that the user must have cloud sync enabled and that their history lives in their chosen cloud drive.

Recommended fix:

- In production, do not silently fall back to local Documents after cloud setup.
- Queue the export locally and mark sync as needing attention.
- Keep local fallback only for tests/previews or explicitly labeled debug builds.

### 10. OAuth / Google Drive Implementation Is Too Concentrated

File:

- `Ironiq/Services/iCloudService.swift`

The same file currently contains iCloud export, Google OAuth, Drive folder management, token storage, and presentation anchor support.

Risks:

- Hard to test independently.
- Token refresh/revocation behavior is incomplete or unclear.
- OAuth failure handling is difficult to reason about.
- Presentation anchor selection may be brittle.

Recommended fix:

- Split into `iCloudDriveStorageProvider`, `GoogleOAuthClient`, `GoogleDriveClient`, `CloudSyncCoordinator`, and `CloudTokenStore`.
- Add tests for expired token, revoked token, missing refresh token, Drive permission denied, and folder deleted remotely.

## Security And Privacy Findings

### Good

- User history is intended to live in the user’s own drive, reducing backend data liability.
- Google tokens appear to be stored in Keychain rather than plain `UserDefaults`.
- The app is not currently exposing a large server-side attack surface for workout history.

### Needs Work

- `UserDefaults` stores sync account metadata. This is not as sensitive as tokens, but it is still personal account metadata and should be treated carefully.
- Google token lifecycle needs stronger refresh/revocation handling.
- Drive export status should be auditable by the user.
- Silent iCloud/local fallback can undermine consent and user expectations.
- Exported workout files should use a stable schema version and avoid accidental sensitive leakage beyond intended workout/health fields.
- Heart-rate data is health-adjacent and should be treated as sensitive. Before adding watch/HealthKit sync, privacy copy, permissions, and export schema should be reviewed carefully.

## Testing Gaps

The suite is large and useful, but it did not catch the startup crash or the original set deletion regression soon enough. That means coverage quantity is not the same as risk coverage.

Recommended additions:

- Launch test with existing store created by previous bundle/schema/configuration.
- Corrupt-store test that asserts backup before rebuild.
- Migration test for every SwiftData model change.
- Cloud setup tests for Apple success, Apple auth error 1000, Google success, Google callback success but folder creation failure, token revoked after setup.
- Provider routing test: Google-selected users export to Google Drive, not iCloud.
- Export failure test: failed session export creates a pending sync job and visible sync warning.
- UI test for active workout route persistence after minimizing and returning from tabs.
- UI test for deleting every set in an exercise and confirming exercise removal.
- UI test preventing duplicate exercise selection in template editor and active workout add flow.
- Device smoke test lane for connected iPhone launch after archive/install, because simulator tests missed TestFlight launch failures.

## Recommended Remediation Plan

### Immediate

- Remove the permanent `Remove Exercise` button and make deleting the final set delete the exercise.
- Add regression tests for that exact behavior.
- Stop silently swallowing sync export failures.
- Add a visible sync status model, even if the UI only shows it in settings for now.
- Make provider-selected exports route through the selected provider.

### Before App Store Release

- Replace destructive startup rebuild with backup-first recovery.
- Add SwiftData migration/corruption tests.
- Add a connected-device launch smoke test to the release checklist.
- Replace session navigation booleans with enum route state.
- Split cloud/auth/storage services into smaller testable components.

### Before Watch / Pro Expansion

- Replace `SessionEngine.current` global with a robust intent/watch command bridge.
- Add HealthKit privacy and export schema review.
- Add sync queue and conflict behavior before watch writes history or session events.
- Decide what happens when users switch from iCloud to Google or vice versa, even if migration remains paid/future.

## Files Worth Reviewing First

- `Ironiq/App/IroniqApp.swift`
- `Ironiq/Services/ModelContainerFactory.swift`
- `Ironiq/App/ContentView.swift`
- `Ironiq/App/AppState.swift`
- `Ironiq/Services/iCloudService.swift`
- `Ironiq/Engine/SessionEngine.swift`
- `Ironiq/ViewModels/SessionViewModel.swift`
- `Ironiq/ViewModels/TemplateViewModel.swift`
- `Ironiq/UI/Components/IroniqTabView.swift`
- `Ironiq/UI/Templates/TemplateEditorView.swift`
- `Ironiq/UI/Session/StartView.swift`

## Bottom Line

The app is moving in the right direction, but the most important engineering work now is making data safety boring and predictable. The UI can keep improving, but the architecture must guarantee that a workout can be logged, saved, exported, recovered, and trusted even when auth, cloud storage, app upgrades, or local persistence misbehave.
