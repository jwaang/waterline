# Ralph Progress Log

This file tracks progress across iterations. Agents update this file
after each iteration and it's included in prompts for context.

## Codebase Patterns (Study These First)

- **SessionSummaryView** is used for both post-session (navigated from ActiveSessionView after endSession) and past session review (navigated from HomeView pastSessionsList). It takes a `sessionId: UUID` and queries via `#Predicate`.
- **Duplicate declarations** have been a recurring issue in this codebase — always check for duplicated `@Query`, `@Environment`, computed properties, and methods before building.
- **Recompute pattern**: When editing/deleting log entries in summary, recompute the `SessionSummary` by replaying all remaining entries in timestamp order, then save to `session.computedSummary`.
- **Navigation routing**: HomeView uses `navigationDestination(for: UUID.self)` to route to either `ActiveSessionView` (if session is active) or `SessionSummaryView` (if ended).
- **SettingsView** requires both `authManager` and `syncService` parameters. Settings changes save to SwiftData immediately and trigger Convex sync via `syncService.triggerSync()`.
- **Sync architecture**: Offline-first with `needsSync` flags on all models. SyncService uses NWPathMonitor for connectivity, auto-syncs on reconnection. All writes go to SwiftData first, then `triggerSync()`. When modifying already-synced records (e.g., ending a session), must re-set `needsSync = true` before saving.
- **WatchConnectivity protocol**: Phone→watch uses `updateApplicationContext` (session state) and `sendMessage`/`transferUserInfo` (presets, reminders). Watch→phone uses `sendMessage` for commands (logWater, logDrink, startSession). Watch has no SwiftData — receives precomputed state and lightweight preset dicts. All watch commands are handled in `WaterlineApp` static methods which create SwiftData entries and call `sendWatchUpdate()` to push refreshed state back.
- **Swift 6 concurrency + WCSessionDelegate**: `[String: Any]` dicts from WCSession delegate methods are not `Sendable`. Bridge via `JSONSerialization.data`→`Data` (Sendable)→decode on MainActor. Don't use `as! Sendable` or `as Sendable` casts.

---

## Feb 13, 2026 - US-022
- SessionSummaryView already existed with full feature set; fixed compilation-blocking duplicate declarations
- Removed: duplicate `@Query private var users`, duplicate `@Environment(\.dismiss)`, duplicate `.toolbar`, duplicate `userSettings` computed property, unused `computePacingAdherence(entries:waterEveryN:)` overload
- Files changed: `Waterline/SessionSummaryView.swift`
- **Learnings:**
  - This file had accumulated duplicates from multiple prior editing passes (likely merge artifacts or copy-paste from parallel workers)
  - The view properly handles all AC: overview stats (drinks, std drinks, water count+volume, duration, pacing adherence %), timeline with edit/delete + recompute, final waterline value, Done button with dismiss
  - SourceKit diagnostics ("Cannot find type in scope") are noise when editing a single file — they resolve on full build
---

## Feb 13, 2026 - US-024
- SettingsView already existed with all 5 required sections (Reminders, Waterline, Defaults, Presets, Account). Two gaps fixed:
  1. Added `syncService` parameter and `syncService.triggerSync()` call in `save()` so settings changes sync to Convex
  2. Added Convex account deletion (`syncService.deleteRemoteAccount`) in `deleteAccount()` before local signout
- Added `deleteRemoteAccount(appleUserId:)` method to SyncService
- Updated HomeView call site to pass `syncService` to SettingsView
- Updated SettingsView #Preview to include syncService
- Files changed: `Waterline/SettingsView.swift`, `Waterline/HomeView.swift`, `Waterline/SyncService.swift`
- **Learnings:**
  - SettingsView was already feature-complete for local-only operation; the missing piece was Convex sync integration
  - SyncService's `convexService` is private, so remote deletion needed a new public method on SyncService rather than exposing ConvexService directly
  - ConvexService is currently nil (not yet configured with deployment URL), so sync calls are effectively no-ops but correctly structured for when it's wired up
---

## Feb 13, 2026 - US-026
- Offline-first sync was already fully implemented across the codebase. One gap fixed:
  - `ActiveSessionView.endSession()` had a placeholder `Task.detached` block instead of calling `syncService.triggerSync()`. Replaced with proper sync trigger and added `session.needsSync = true` to ensure ended sessions re-sync.
- Verified all 4 acceptance criteria already met:
  1. All log entries write to SwiftData first (every `logWater`, `logPreset`, `LogDrinkView` flow)
  2. Background sync queue with NWPathMonitor, `needsSync` flags, auto-sync on reconnection
  3. Last-write-wins conflict resolution via timestamp-based upserts
  4. SyncStatusIndicator in toolbar of both HomeView and ActiveSessionView (cloud icons with states)
- Files changed: `Waterline/ActiveSessionView.swift`
- **Learnings:**
  - When modifying an already-synced record (e.g., setting `session.isActive = false`), you must explicitly set `needsSync = true` again — SwiftData property changes don't auto-reset custom sync flags
  - The sync architecture is well-designed: `SyncService` handles sessions first (dependency ordering), then log entries, then presets, with per-item error tolerance and retry on next cycle
---

## Feb 13, 2026 - US-027
- Implemented Apple Watch main screen with full quick-logging capability
- Watch active session view: compact Waterline gauge + drink/water counts + "+ Drink" and "+ Water" buttons
- "+ Water" immediately sends `logWater` command to phone via WatchConnectivity
- "+ Drink" opens preset picker sheet (shows user presets from phone, or fallback defaults: Beer, Wine, Shot, Cocktail, Double)
- No active session state: shows "Start Session" button that creates a session on the phone
- Haptic confirmation: `.click` on log actions, `.success` on session start, `.notification` on water reminders
- Phone sends session state via `updateApplicationContext` and presets via `sendMessage`/`transferUserInfo` after every watch command
- New `handleWatchLogDrink` handler creates alcohol LogEntry with preset metadata, checks per-drink + pacing warnings
- New `handleWatchStartSession` handler creates Session, schedules reminders, associates with user
- Files changed: `WaterlineWatch/WatchContentView.swift`, `WaterlineWatch/WatchSessionManager.swift`, `Waterline/WatchConnectivityManager.swift`, `Waterline/WaterlineApp.swift`
- **Learnings:**
  - WatchConnectivity `[String: Any]` dicts are not `Sendable` in Swift 6 strict concurrency. Cannot cast `Any` to `Sendable`. Solution: serialize to `Data` via `JSONSerialization` (which is `Sendable`) then deserialize on the MainActor side.
  - `sendSessionState` was defined but never called — the watch was a display-only shell. Watch state updates must be explicitly pushed after every data mutation (both watch-originated and phone-originated commands).
  - Watch app doesn't share SwiftData models — it uses lightweight `WatchPreset` structs deserialized from dictionaries. Keep watch-side data structures minimal and independent.
  - Default drink presets are hardcoded as fallback in WatchContentView for when phone hasn't synced presets yet (e.g., first launch or watch not reachable).
---
