# Ralph Progress Log

This file tracks progress across iterations. Agents update this file
after each iteration and it's included in prompts for context.

## Codebase Patterns (Study These First)

### Convex HTTP API Pattern (ConvexService.swift)
- `ConvexService` is an `actor` wrapping Convex HTTP API via `URLSession` async/await
- Generic `callFunction<T: Decodable>()` handles both queries and mutations
- DTOs use `toDictionary()` for serialization (no Encodable → [String:Any] bridge needed)
- Response envelope: `ConvexResponse<T>` with `status` ("success"/"error"), `value`, `errorMessage`
- `ConvexNull` sentinel type for void mutations

### Convex TypeScript Structure
- `convex/schema.ts` — defineSchema with tables matching SwiftData models
- `convex/mutations.ts` — CRUD mutations (createUser, upsertSession, addLogEntry, deleteLogEntry, upsertDrinkPreset)
- `convex/queries.ts` — read queries (getActiveSession, getSessionLogs, getUserPresets)
- `convex/auth.ts` — custom Sign in with Apple auth (verifyAndCreateUser, getUserByAppleId)
- `_generated/` directory only exists after `npx convex dev` (requires deployment auth)

### XcodeGen + Swift Testing
- `project.yml` defines all targets; run `xcodegen generate` to regenerate `.xcodeproj`
- Tests use Swift Testing framework (`@Test`, `@Suite`, `#expect`)
- Test target `WaterlineTests` depends on `Waterline` target

### Sheet-Based Logging Pattern (LogDrinkView.swift)
- Logging flows use `@State private var showingSheet = false` + `.sheet(isPresented:)` on the button container
- Pass session object and `onLogged` callback for post-log side effects (reminders, sync)
- Waterline state is fully computed from `session.logEntries` — no separate state tracking needed; `@Query` auto-refreshes views

### Per-Drink Water Reminder Pattern
- After logging a drink, compute `alcoholCountSinceLastWater` and compare to `userSettings.waterEveryNDrinks`
- If threshold met, fire `UNNotificationRequest` with `UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)` for immediate delivery

### Home Screen Navigation Pattern (HomeView.swift)
- `HomeView` uses `@Query` with `#Predicate { !$0.isActive }` and `SortDescriptor(\Session.startTime, order: .reverse)` to fetch past sessions
- `NavigationStack` with `NavigationLink(value: session.id)` + `.navigationDestination(for: UUID.self)` for type-safe navigation to `SessionSummaryView`
- `PastSessionRow` reads from `computedSummary` when available, falls back to counting `logEntries` — dual-path display for sessions ended with/without summary
- Past sessions list limited via `.prefix(5)` on the view side rather than `fetchLimit` in the query — simpler and avoids SwiftData fetch descriptor limitations

### Navigation Routing Pattern (HomeView.swift)
- Single `.navigationDestination(for: UUID.self)` at `NavigationStack` root — SwiftUI only allows one per type
- `sessionDestination(for:)` router checks `activeSessions` array to dispatch: active → `ActiveSessionView`, past → `SessionSummaryView`
- `NavigationPath` state enables programmatic push via `.append(uuid)` after session creation
- All `NavigationLink(value: session.id)` throughout the view hierarchy share the same destination handler

### Time-Based Reminder Pattern (ReminderService.swift)
- `ReminderService` is a `static enum` (no instances) providing `scheduleTimeReminders()`, `cancelAllTimeReminders()`, `rescheduleInactivityCheck()`
- Uses `UNTimeIntervalNotificationTrigger(repeats: true)` for recurring reminders at user-configured interval
- Notification category `WATER_REMINDER` registered at app launch with "Log Water" and "Dismiss" actions — shared by both time-based and per-drink reminders
- 90-minute inactivity auto-stop: a one-shot notification fires after 90 minutes; on delivery, `handleInactivityTimeout()` cancels all time reminders
- Each log entry calls `rescheduleInactivityCheck()` to reset the 90-minute timer
- `NotificationDelegate` handles "Log Water" action by fetching active session from `ModelContainer.mainContext` and creating a water `LogEntry`
- `WaterlineApp` creates a shared `ModelContainer` and passes it to both the SwiftUI scene and `NotificationDelegate`

### Pacing Warning Pattern (ReminderService.swift)
- `ReminderService.schedulePacingWarning()` fires an immediate notification when waterline crosses `warningThreshold`
- Threshold crossing detection: `previousValue = currentValue - addedEstimate`; fire only when `previousValue < threshold && currentValue >= threshold`
- Called from `checkPacingWarning(for:addedEstimate:)` in both `ActiveSessionView` and `HomeView` after any drink log
- Reuses `WATER_REMINDER` category — no separate category needed for pacing warnings
- `LogDrinkView.onLogged` signature is `(Double) -> Void` — passes `adjustedEstimate` for downstream threshold checks

### Auth Pattern (AuthenticationManager.swift)
- `AuthenticationManager` is `@Observable @MainActor` — drives SwiftUI reactive auth state
- Uses `AuthCredentialStore` protocol for storage injection (Keychain in prod, in-memory for tests)
- `KeychainStore` is the production implementation; `InMemoryCredentialStore` for unit tests
- Auth flow: `SignInWithAppleButton` → `handleAuthorization()` → Keychain + SwiftData + Convex sync
- `restoreSession()` called on app launch to hydrate from Keychain
- Convex sync is fire-and-forget (non-fatal failure) — local SwiftData is authoritative

### Offline-First Sync Pattern (SyncService.swift)
- `SyncService` is `@Observable @MainActor` — exposes `status: SyncStatus` and `pendingCount: Int` for UI binding
- All SwiftData models (`Session`, `LogEntry`, `DrinkPreset`) have `needsSync: Bool` field (default `true`) — marks items pending sync
- `NWPathMonitor` on background queue detects connectivity; triggers sync on connectivity restoration
- Sync engine creates a fresh `ModelContext` from `ModelContainer`, queries `needsSync == true`, pushes to Convex, then marks `needsSync = false` on success
- Conflict resolution: last-write-wins via Convex `upsertSession`/`upsertDrinkPreset` with `existingId` parameter
- `SyncStatusIndicator` view shows subtle cloud icon with four states: idle (checkmark), syncing (animated), offline (slash), error (exclamation)
- `syncService.triggerSync()` called after every data mutation in views (log water, log drink, log preset, delete entry, start session)
- `SyncService` threaded through view hierarchy: `WaterlineApp` → `RootView` → `HomeView` → `ActiveSessionView`
- After `xcodegen generate`, new Swift files are auto-included from `path: Waterline` source glob

---

## Feb 12, 2026 - US-003
- What was implemented:
  - Convex backend schema (`convex/schema.ts`) matching SwiftData models: users, sessions, logEntries, drinkPresets
  - CRUD mutation functions (`convex/mutations.ts`): createUser, upsertSession, addLogEntry, deleteLogEntry, upsertDrinkPreset
  - Query functions (`convex/queries.ts`): getActiveSession, getSessionLogs, getUserPresets
  - Custom Sign in with Apple auth (`convex/auth.ts`): verifyAndCreateUser, getUserByAppleId
  - Swift ConvexService actor wrapping HTTP API with async/await (`Waterline/ConvexService.swift`)
  - Comprehensive test suite for ConvexService DTOs, response parsing, and error handling (19 tests)
  - npm package.json with convex dependency, TypeScript config
- Files changed:
  - `convex/schema.ts`, `convex/mutations.ts`, `convex/queries.ts`, `convex/auth.ts`, `convex/tsconfig.json` (pre-existing)
  - `Waterline/ConvexService.swift` (pre-existing)
  - `package.json` (pre-existing)
  - `WaterlineTests/WaterlineTests.swift` (added 19 ConvexService tests)
- **Learnings:**
  - Convex `_generated/server` module only exists after `npx convex dev` runs with deployment auth — TS type-checking will fail pre-deployment but code is structurally correct
  - Convex HTTP API uses POST to `/api/query` and `/api/mutation` with `{path, args, format}` body
  - ConvexService uses `actor` isolation for thread safety — tests accessing properties need `await`
  - `ConvexNull` pattern handles void mutation returns cleanly with forced cast `ConvexNull() as! T`
---

## Feb 12, 2026 - US-004
- What was implemented:
  - `AuthenticationManager` (`@Observable @MainActor`) managing Sign in with Apple flow, Keychain persistence, local user creation, and Convex sync
  - `AuthCredentialStore` protocol with `KeychainStore` (production) and `InMemoryCredentialStore` (tests) — injectable for testability
  - `SignInView` with `SignInWithAppleButton`, error alert with retry
  - `RootView` routing between `SignInView` / `ContentView` based on `AuthState`
  - `WaterlineApp` wired to create `AuthenticationManager` and call `restoreSession()` on appear
  - 14 new tests: AuthState equality/hashable, initialization, session restore (empty/populated), sign out, credential store CRUD, local user creation and dedup
- Files changed:
  - `Waterline/AuthenticationManager.swift` (new)
  - `Waterline/SignInView.swift` (new)
  - `Waterline/ContentView.swift` (modified — added `RootView`, kept `ContentView`)
  - `Waterline/WaterlineApp.swift` (modified — added `AuthenticationManager` state, `RootView`)
  - `WaterlineTests/WaterlineTests.swift` (added 14 auth tests)
- **Learnings:**
  - Keychain APIs (`SecItemAdd`/`SecItemCopyMatching`) don't work in the Xcode test runner sandbox — must inject storage via protocol
  - `@Observable @MainActor` class works well for auth state that drives SwiftUI view transitions
  - `ASAuthorizationAppleIDCredential` can't be easily mocked — test the state management layer separately from the Apple credential handling
  - Swift 6 strict concurrency: `InMemoryCredentialStore` needs `@unchecked Sendable` since it has mutable state accessed synchronously in tests
---

## Feb 12, 2026 - US-005
- What was implemented:
  - `OnboardingView` coordinator managing page state via `OnboardingPage` enum (welcome → guardrail → signIn)
  - `WelcomeScreen` with app value proposition, drop icon, and "Continue" button
  - `GuardrailScreen` with pacing tool disclaimer, hand.raised icon, and "I understand" button
  - `RootView` updated with `@AppStorage("hasCompletedOnboarding")` to route new vs returning users
  - `.onChange(of: authManager.isSignedIn)` sets flag to true on successful sign-in
  - 8 tests across 3 suites: OnboardingPage ordering/hashability, UserDefaults persistence, and integration flow
- Files changed:
  - `Waterline/OnboardingView.swift` (new)
  - `Waterline/ContentView.swift` (modified — RootView routes through onboarding for new users)
  - `WaterlineTests/WaterlineTests.swift` (added OnboardingPage, OnboardingPersistence, OnboardingFlow test suites)
- **Learnings:**
  - `@AppStorage` with a simple boolean flag is the cleanest way to persist "onboarding shown once" state — no need for SwiftData or Keychain
  - Onboarding tests can use unique `UserDefaults(suiteName:)` per test for isolation, with `removePersistentDomain` cleanup
  - SwiftUI `Group` + `switch` + `.animation(value:)` pattern works well for page-based onboarding flows without NavigationStack overhead
  - Embedding `SignInView` as the final onboarding page avoids duplicating the sign-in UI
---

## Feb 12, 2026 - US-006
- What was implemented:
  - `ConfigureDefaultsView` with all settings controls: water every N drinks (stepper, 1-10), time-based reminders toggle + interval picker (10/15/20/30/45/60 min), warning threshold (stepper, 1-10), units (oz/ml segmented picker)
  - `NotificationPermissionView` sheet with explanation text and Enable/Skip buttons, shown conditionally when time reminders are enabled
  - Settings saved to `UserSettings` via SwiftData by fetching the authenticated user by `appleUserId`
  - `RootView` updated: signed-in + not onboarded → `ConfigureDefaultsView`; "Done" callback sets `hasCompletedOnboarding = true`; removed old `onChange(of: isSignedIn)` auto-complete
  - 11 new tests across 2 suites: ConfigureDefaults Settings Persistence (8 tests) and ConfigureDefaults Onboarding Completion (3 tests)
  - Updated existing onboarding flow test to match new behavior (sign-in no longer auto-completes onboarding)
  - XcodeGen regenerated to include new file
  - All 75 tests pass across 24 suites
- Files changed:
  - `Waterline/ConfigureDefaultsView.swift` (new)
  - `Waterline/ContentView.swift` (modified — RootView shows ConfigureDefaultsView for signedIn + !onboarded)
  - `WaterlineTests/WaterlineTests.swift` (added 11 tests, updated 1 existing test)
- **Learnings:**
  - XcodeGen auto-includes new `.swift` files from `path: Waterline` source glob, but `xcodegen generate` must be re-run for the Xcode project to pick them up
  - Configure defaults fits cleanly as a `signedIn + !hasCompletedOnboarding` branch in RootView rather than as another OnboardingPage — keeps auth state routing simple
  - Notification permission request is best shown conditionally (only when time reminders enabled) to avoid unnecessary prompts
  - SwiftData `User` settings can be updated by fetching the user by `appleUserId` and mutating embedded `UserSettings` struct fields directly — SwiftData tracks the changes
  - `.sheet(isPresented:)` with `presentationDetents([.medium])` works well for a focused notification explanation modal
---

## Feb 12, 2026 - US-007
- What was implemented:
  - `HomeView` with prominent "Start Session" CTA, settings gear icon in toolbar, and past sessions list (last 5, sorted by most recent)
  - `PastSessionRow` displaying date, duration, drink count, and water count from `computedSummary` or fallback to `logEntries`
  - Empty state message when no past sessions exist
  - `SessionSummaryView` with session overview (date, duration, drinks, water, pacing adherence, final waterline) via `@Query` filtered by session ID
  - `RootView` updated: `HomeView()` replaces old placeholder `ContentView()` for signed-in + onboarded users
  - 8 new tests across 3 suites: Home Screen Past Sessions Query (4 tests), Home Screen Session Row Data (3 tests), Home Screen Routing (1 test)
  - All 82 tests pass across 25 suites
- Files changed:
  - `Waterline/HomeView.swift` (new)
  - `Waterline/SessionSummaryView.swift` (new)
  - `Waterline/ContentView.swift` (modified — RootView routes to HomeView, removed old ContentView placeholder)
  - `WaterlineTests/WaterlineTests.swift` (added 8 tests, updated 2 comments)
- **Learnings:**
  - `@Query` with `#Predicate` in SwiftUI view uses `$0.isActive` directly — no need for `FetchDescriptor` wrapper when the query is static
  - `.prefix(5)` on `@Query` results is simpler than `fetchLimit` in the query descriptor for view-level display limits
  - `NavigationLink(value:)` + `.navigationDestination(for:)` pattern works cleanly with UUID-based session navigation
  - `SessionSummaryView` initializer with `@Query` filter by UUID requires init-time `_sessions = Query(filter:)` pattern — the predicate must capture the parameter
  - Removed old `ContentView` struct entirely since it was just a placeholder — `HomeView` is the real home screen now
---

## Feb 12, 2026 - US-008
- What was implemented:
  - `HomeView` updated with conditional rendering: active session state vs no-session state
  - Second `@Query` added filtering `$0.isActive` to detect active sessions
  - `WaterlineIndicator` view: vertical gauge with center line, fill from center (orange up/blue down), red warning at threshold ≥2, animated transitions, accessibility labels
  - Active session shows: Waterline indicator, drink/water counts, "+ Drink" / "+ Water" quick-add buttons (action stubs for US-012/013/014), "View Session" NavigationLink
  - Waterline value computed inline from session's `logEntries` sorted by timestamp (alcohol += standardDrinkEstimate, water -= 1)
  - Session auto-recovery inherent — SwiftData `@Query` automatically finds persisted active sessions on relaunch
  - 9 new tests across 3 suites: Active Session Detection (3), Waterline Computation (4), Warning State (2)
  - All 91 tests pass across 28 suites
- Files changed:
  - `Waterline/HomeView.swift` (modified — added active session state, WaterlineIndicator, waterline computation)
  - `WaterlineTests/WaterlineTests.swift` (added 9 tests)
- **Learnings:**
  - Multiple `@Query` properties in a single SwiftUI view work well for mutually exclusive states (active vs past sessions)
  - `WaterlineIndicator` uses `GeometryReader` for proportional fill calculation — clamped to ±5 range for visual bounds, with `clipShape` to contain the fill within the rounded rectangle track
  - Waterline computation from log entries mirrors PRD FR-4 algorithm exactly — will be extracted to `WaterlineEngine` in US-034 for reuse across all surfaces
  - Quick-add button actions left as stubs (comments reference US-012/013/014) — buttons are visible and tappable but don't log yet
  - Warning threshold hardcoded to 2 (matching `UserSettings` default) — will need to read from user settings when full session screen is built
---

## Feb 12, 2026 - US-009
- What was implemented:
  - `startSession()` function in `HomeView` that creates a new `Session` with `startTime = now`, `isActive = true`, inserts into SwiftData, and navigates to `ActiveSessionView`
  - Single-active-session constraint: checks `activeSessions.first` before creating; if active session exists, navigates to it instead
  - `ActiveSessionView` — dedicated view for active session display using `@Query` filter by session ID, with waterline indicator, drink/water counts, and quick-add button stubs (US-012/013/014)
  - `NavigationPath`-based programmatic navigation: "Start Session" pushes to `ActiveSessionView`, past session taps push to `SessionSummaryView`
  - Unified `sessionDestination(for:)` router that checks if session is active to choose `ActiveSessionView` vs `SessionSummaryView` — resolves single `.navigationDestination(for: UUID.self)` constraint
  - Convex sync placeholder via fire-and-forget `Task.detached` — will be wired when `ConvexService` is available in environment (US-026)
  - Live Activity trigger comment placeholder for US-032
  - 8 new tests across 3 suites: Start Session Creation (3), Single Active Session Constraint (3), Start Session Navigation (2)
  - All 99 tests pass across 31 suites
- Files changed:
  - `Waterline/HomeView.swift` (modified — added startSession(), syncSessionToConvex(), sessionDestination(), NavigationPath)
  - `Waterline/ActiveSessionView.swift` (new — placeholder active session screen)
  - `WaterlineTests/WaterlineTests.swift` (added 8 tests)
- **Learnings:**
  - SwiftUI `NavigationStack` only supports one `.navigationDestination(for: Type.self)` per type in the hierarchy — must use a single routing function to dispatch to different views based on data state
  - `NavigationPath` with `.append(uuid)` enables programmatic navigation after session creation without needing `@Binding` or `NavigationLink(isActive:)`
  - The active session check (`activeSessions.first`) is already reactive via `@Query` — no need for manual refresh after insert since SwiftData triggers view update
  - Convex sync pattern follows auth precedent: fire-and-forget with non-fatal failure — local SwiftData is authoritative
---

## Feb 12, 2026 - US-010
- What was implemented:
  - `WaterlineIndicator` enhanced with configurable `warningThreshold` parameter (default: 2, matching UserSettings default)
  - `HomeView` now reads user's `warningThreshold` from `@Query` on `User` model and passes to indicator
  - `ActiveSessionView` similarly reads user settings for dynamic threshold
  - 15 new tests across 2 suites: Waterline Indicator Rendering Logic (11 tests covering values -3, 0, 1, 2, 3, 5, custom thresholds, fill direction, clamping) and Waterline Indicator with Session Data (4 tests verifying indicator behavior with real SwiftData sessions)
  - All 114 tests pass across 33 suites
- Files changed:
  - `Waterline/HomeView.swift` (modified — added `@Query` for users, `warningThreshold` computed property, parameterized `WaterlineIndicator`)
  - `Waterline/ActiveSessionView.swift` (modified — added `@Query` for users, `warningThreshold` computed property, parameterized `WaterlineIndicator`)
  - `WaterlineTests/WaterlineTests.swift` (added 15 tests)
- **Learnings:**
  - `WaterlineIndicator` was already built in US-008 with hardcoded threshold — US-010 primarily added dynamic threshold from UserSettings and comprehensive tests
  - Adding `@Query private var users: [User]` to views that need settings is the cleanest SwiftUI pattern — no need to pass settings through init
  - Default parameter values on SwiftUI view properties (`var warningThreshold: Int = 2`) maintain backward compatibility with existing call sites
  - The indicator's visual logic (GeometryReader fill, clamping to ±5, center-relative positioning) was already correct from US-008 — tests validated all edge cases
---

## Feb 12, 2026 - US-011
- What was implemented:
  - `ActiveSessionView` enhanced with reminder status section: "Water due in: X drinks" pacing counter and "Next reminder: X:XX" countdown timer
  - `HomeView` active session content updated with same reminder status section for consistency
  - `alcoholCountSinceLastWater()` computation: iterates log entries in timestamp order, counts alcohol entries, resets on water
  - `nextReminderCountdown()` computation: calculates time from last log entry (or session start) plus interval, formats as "M:SS" or "now"
  - `@State private var now = Date()` with 1-second Timer for live countdown updates in both views
  - `userSettings` computed property replaces separate `warningThreshold` — provides access to all settings (waterEveryNDrinks, timeRemindersEnabled, timeReminderIntervalMinutes)
  - 15 new tests across 4 suites: Alcohol Count Since Last Water (5), Water Due In Drinks Calculation (4), Next Time-Based Reminder Countdown (4), Counters Update on Log Addition (2)
  - All 129 tests pass across 37 suites
- Files changed:
  - `Waterline/ActiveSessionView.swift` (modified — added reminder status section, timer, pacing computation)
  - `Waterline/HomeView.swift` (modified — added reminder status section, timer, pacing computation)
  - `WaterlineTests/WaterlineTests.swift` (added 15 tests)
- **Learnings:**
  - Timer-based countdown tests must use a fixed reference `Date()` captured once, not `Date()` at multiple call sites — avoids sub-second timing drift causing "17:59" vs "18:00" failures
  - `Timer.publish(every: 1, on: .main, in: .common).autoconnect()` with `onReceive` is the standard SwiftUI pattern for live countdown displays — no need for `ObservableObject` or custom timer manager
  - `alcoholCountSinceLastWater` must process entries in timestamp order (same as waterline computation) — the running count resets on each water entry, leaving only the count since the most recent water
  - Reminder countdown uses last log entry timestamp as the anchor, not session start — this means the countdown "resets" each time the user logs anything, which is intuitive (you just interacted, so the next reminder is interval-from-now)
---

## 2026-02-12 - US-012
- What was implemented:
  - Full alcoholic drink logging flow: drink type picker (beer/wine/liquor/cocktail segmented), size presets per type, adjustable standard drink estimate (+/- 0.5 in range 0.5-5.0), confirm button
  - `LogDrinkView` presented as sheet from both `ActiveSessionView` and `HomeView` "+ Drink" buttons
  - On confirm: `LogEntry` created with `type: .alcohol`, `alcoholMeta` (drinkType, sizeOz, standardDrinkEstimate), `source: .phone`, linked to session via relationship
  - Per-drink water reminder: after logging, checks `alcoholCountSinceLastWater >= waterEveryNDrinks` and fires local notification via `UNUserNotificationCenter`
  - Size presets from PRD: beer 12oz(1.0)/16oz(1.3)/pint 20oz(1.7), wine 5oz(1.0)/glass 6oz(1.2), liquor 1.5oz(1.0)/double 3oz(2.0), cocktail standard(1.0)/strong(1.5)
  - Waterline value update, warning state, and counter updates are automatic via existing computed properties iterating `session.logEntries`
  - Convex background sync deferred to US-026 (offline-first sync), consistent with existing patterns
- Files changed:
  - `Waterline/LogDrinkView.swift` (new) — drink type picker, size presets, estimate adjuster, LogEntry creation
  - `Waterline/ActiveSessionView.swift` (modified) — wired "+ Drink" button to sheet, added per-drink reminder logic, added UserNotifications import
  - `Waterline/HomeView.swift` (modified) — wired "+ Drink" button to sheet, added per-drink reminder logic, added UserNotifications import
- **Learnings:**
  - `DrinkType` already has `CaseIterable` conformance in Models.swift, enabling easy `ForEach` iteration in segmented picker
  - `@Query` in ActiveSessionView auto-refreshes when new `LogEntry` objects are inserted with session relationship set — counters/waterline update immediately without manual state management
  - `onChange(of:)` in Swift 6 uses no-parameter closure syntax: `onChange(of: selectedType) { ... }` not `onChange(of: selectedType) { oldValue, newValue in ... }`
  - Sheet presentation works best when `.sheet(isPresented:)` is attached to the parent container (HStack) rather than individual buttons
---

## 2026-02-12 - US-013
- What was implemented:
  - Water logging wired into both `ActiveSessionView` and `HomeView` "+ Water" quick-add buttons (previously stubs)
  - `logWater(for:)` function creates `LogEntry` with `type: .water`, `waterMeta.amountOz` from `userSettings.defaultWaterAmountOz`, `source: .phone`, sets session relationship, inserts into SwiftData
  - Waterline decrease (-1), `alcoholCountSinceLastWater` reset to 0, and warning state clearing all work automatically via existing computed properties that iterate `session.logEntries`
  - Convex background sync deferred to US-026 (offline-first sync), consistent with prior stories
- Files changed:
  - `Waterline/ActiveSessionView.swift` (modified — wired water button, added `logWater(for:)`)
  - `Waterline/HomeView.swift` (modified — wired water button, added `logWater(for:)`)
- **Learnings:**
  - Water logging is significantly simpler than drink logging (US-012) because it needs no picker/sheet — single tap creates the entry directly
  - All reactive state updates (waterline value, counts, warning state, pacing counter) are already handled by existing computed properties over `session.logEntries` — adding a new `LogEntry` to SwiftData triggers `@Query` refresh automatically
  - The `logWater` function is identical in both views — potential extraction to a shared helper when `WaterlineEngine` is built in US-034
---

## 2026-02-12 - US-014
- What was implemented:
  - Haptic feedback (`UIImpactFeedbackGenerator(style: .medium)`) added to both "+ Drink" and "+ Water" quick-add buttons in `ActiveSessionView` and `HomeView`
  - Button sizing updated from `.padding(.vertical, 14)` to `.frame(minHeight: 44)` to explicitly guarantee the 44pt minimum tap target per Apple HIG
  - All other acceptance criteria (bottom placement, single-tap water logging, sheet-based drink logging) were already implemented in US-012 and US-013
- Files changed:
  - `Waterline/ActiveSessionView.swift` (modified — haptic feedback + minHeight on quick-add buttons)
  - `Waterline/HomeView.swift` (modified — haptic feedback + minHeight on quick-add buttons)
- **Learnings:**
  - US-014 was largely a UX polish story — the functional buttons, sheet flow, and positioning were already built in US-008/012/013
  - `.frame(minHeight: 44)` is more semantically correct than `.padding(.vertical, 14)` for enforcing Apple's minimum tap target — the padding approach depends on font size, while minHeight is an absolute guarantee
  - `UIImpactFeedbackGenerator(style: .medium)` is appropriate for confirmation actions like logging; `.light` would be too subtle, `.heavy` too aggressive
---

## 2026-02-12 - US-015
- What was implemented:
  - `PresetsListView` — settings screen section "Quick Drinks" with list of presets, swipe-to-delete, tap-to-edit, and "+" toolbar button for adding new presets
  - `AddEditPresetView` — form for creating/editing presets with name, drink type (segmented picker), size (oz), optional ABV, and adjustable standardDrinkEstimate (+/- 0.5, range 0.5-5.0)
  - Presets saved as `DrinkPreset` in SwiftData with user relationship; Convex sync deferred to US-026 (offline-first sync) consistent with existing patterns
  - Preset chips displayed as horizontally-scrollable capsule buttons on both `ActiveSessionView` and `HomeView` above the quick-add buttons
  - Single-tap preset logging: tapping a chip immediately creates a `LogEntry` with full `AlcoholMeta` (including `presetId`) and triggers per-drink water reminder check
  - Settings gear button in `HomeView` toolbar wired to navigate to `PresetsListView` (will be replaced by full `SettingsView` in US-024)
  - Haptic feedback on preset chip tap, consistent with quick-add button pattern
- Files changed:
  - `Waterline/AddEditPresetView.swift` (new) — preset create/edit form
  - `Waterline/PresetsListView.swift` (new) — presets list with CRUD operations
  - `Waterline/ActiveSessionView.swift` (modified — added `@Query` for presets, preset chips section, `logPreset()`)
  - `Waterline/HomeView.swift` (modified — added `@Query` for presets, preset chips section, `logPreset()`, settings navigation)
- **Learnings:**
  - `@Query private var presets: [DrinkPreset]` without a filter fetches all presets — works because presets are per-user and the app is single-user; multi-user would need a user filter
  - `ScrollView(.horizontal, showsIndicators: false)` with `HStack` is the standard pattern for horizontally-scrollable chip rows in SwiftUI
  - `Capsule().fill()` + `Capsule().strokeBorder()` layered via `.background()` + `.overlay()` creates clean chip styling without complex Shape composition
  - `.sheet(item: $presetToEdit)` with `DrinkPreset` works because `@Model` classes conform to `Identifiable` — enables edit-on-tap without manual id tracking
  - `logPreset()` mirrors the existing `logDrink()` pattern but populates `AlcoholMeta.presetId` to link the log entry back to its source preset for future analytics
  - Settings gear button uses `NavigationLink` (destination-based) instead of `Button` + programmatic navigation — simpler and avoids needing additional state management
---

## 2026-02-12 - US-016
- What was implemented:
  - Default drink presets created during onboarding completion in `ConfigureDefaultsView.completeOnboarding()`: "Beer" (12oz, 1.0 std), "Glass of Wine" (5oz, 1.0 std), "Shot" (1.5oz, 1.0 std), "Cocktail" (6oz, 1.0 std), "Double" (3oz, 2.0 std)
  - Guard clause skips creation if user already has presets (idempotent for Convex sync restore scenarios)
  - Presets are standard `DrinkPreset` objects — fully editable and deletable via `PresetsListView` from US-015
- Files changed:
  - `Waterline/ConfigureDefaultsView.swift` (modified — added `createDefaultPresets()` called from `completeOnboarding()`)
- **Learnings:**
  - Default presets belong in the onboarding completion flow (`completeOnboarding()`) rather than in app launch or HomeView — this ensures they exist exactly once after onboarding and before the user reaches the home screen
  - No special "isDefault" flag needed on `DrinkPreset` — default presets are regular user presets that happen to be pre-created, keeping the model simple and the presets fully user-owned
  - Guard `!user.presets.isEmpty` prevents duplicate creation if `completeOnboarding()` is somehow called twice or presets were restored from Convex sync
---

## 2026-02-12 - US-017
- What was implemented:
  - Log timeline in `ActiveSessionView` with reverse-chronological entries, swipe-to-delete, and tap-to-edit via sheet
  - Same log timeline in `SessionSummaryView` with chronological entries, swipe-to-delete, tap-to-edit, and automatic `computedSummary` recomputation on changes
  - `EditLogEntryView` — sheet for editing alcohol entries (type, size, estimate) or water entries (amount), reusing the same UI patterns as `LogDrinkView`
  - `LogEntryRow` — shared row component displaying entry type icon, details (drink type, size, std estimate or water amount), and timestamp
  - Waterline and all counters recompute automatically on edit/delete: in `ActiveSessionView` via computed properties over `session.logEntries` (SwiftData `@Query` auto-refresh), in `SessionSummaryView` via explicit `recomputeSummary()` call
  - Convex sync deferred to US-026 (offline-first sync), consistent with all prior stories
- Files changed:
  - `Waterline/EditLogEntryView.swift` (new) — edit sheet for alcohol and water log entries
  - `Waterline/LogEntryRow.swift` (new) — shared log entry row component
  - `Waterline/ActiveSessionView.swift` (modified — added `entryToEdit` state, `logTimeline()`, `deleteEntries()`, edit sheet)
  - `Waterline/SessionSummaryView.swift` (modified — added timeline section, edit/delete, `recomputeSummary()`, live-computed overview values)
- **Learnings:**
  - `@Model` classes conform to `Identifiable` automatically, so `.sheet(item:)` works directly with `LogEntry?` state — no manual id tracking needed
  - Active session doesn't need explicit recomputation because all displayed values (waterline, counts, pacing) are computed properties iterating `session.logEntries` which SwiftData auto-refreshes on any insert/delete
  - `SessionSummaryView` needs explicit `recomputeSummary()` because `computedSummary` is a stored property on `Session` — it doesn't auto-update when log entries change
  - `.sheet(item:, onDismiss:)` is the correct syntax for combining item-based presentation with dismiss callback — the trailing closure variant `{ _ in }` doesn't compile
  - Timeline in active session uses reverse-chronological (newest first) for quick glance at recent entries; summary uses chronological (oldest first) for narrative review
  - `List` with `.frame(maxHeight:)` inside a `VStack` creates a bounded scrollable timeline without taking over the full screen
---

## 2026-02-12 - US-018
- What was implemented:
  - `ReminderService` (new): centralized enum with static methods for scheduling/canceling time-based reminders, registering notification categories, and 90-minute inactivity detection
  - `NotificationDelegate` (new): `UNUserNotificationCenterDelegate` handling "Log Water" action from notifications — creates water `LogEntry` in active session via shared `ModelContainer`
  - `WaterlineApp` updated: creates shared `ModelContainer`, registers notification category at launch, sets `NotificationDelegate` as delegate with container reference
  - `HomeView.startSession()` updated: schedules time-based reminders when `timeRemindersEnabled` is true using `ReminderService.scheduleTimeReminders()`
  - All log entry functions in `ActiveSessionView` and `HomeView` (logWater, logPreset, LogDrinkView onLogged) call `ReminderService.rescheduleInactivityCheck()` to reset the 90-minute inactivity timer
  - Per-drink reminder `categoryIdentifier` updated from hardcoded `"WATER_REMINDER"` to `ReminderService.categoryIdentifier` for shared action handling
  - `cancelAllTimeReminders()` is available for US-021 (End Session) to call when session ends
- Files changed:
  - `Waterline/ReminderService.swift` (new) — time-based reminder scheduling, cancellation, inactivity detection
  - `Waterline/NotificationDelegate.swift` (new) — notification action handling, "Log Water" creates LogEntry
  - `Waterline/WaterlineApp.swift` (modified — shared ModelContainer, category registration, delegate setup)
  - `Waterline/HomeView.swift` (modified — schedule reminders on session start, inactivity reschedule on logs, shared category identifier)
  - `Waterline/ActiveSessionView.swift` (modified — inactivity reschedule on logs, shared category identifier)
- **Learnings:**
  - `UNTimeIntervalNotificationTrigger(repeats: true)` is the simplest way to schedule recurring notifications — iOS handles the repeat loop, no manual rescheduling needed
  - `UNNotificationCategory` must be registered with `setNotificationCategories` at app launch (before any notifications fire) — it replaces all existing categories, so all categories must be in one call
  - For the `NotificationDelegate` to create `LogEntry` objects, it needs access to the `ModelContainer` — passing it from `WaterlineApp.init()` is cleaner than creating a second container
  - `WaterlineApp` can't use `.modelContainer()` scene modifier AND access the container in `init()` simultaneously — solution is to create the container in `init()` and pass it to `.modelContainer(sharedModelContainer)` explicitly
  - 90-minute inactivity detection uses a scheduled notification as a timer rather than in-process `Timer` — this works even when the app is backgrounded or killed
  - `nonisolated` on `UNUserNotificationCenterDelegate` methods is required in Swift 6 strict concurrency when the class is `@MainActor` — the delegate methods are called from the notification system's thread
---

## 2026-02-13 - US-020
- What was implemented:
  - Pacing warning notification: fires a local notification when waterline value crosses the `warningThreshold` upward (was below, now at or above)
  - `ReminderService.schedulePacingWarning()` — new static method that fires an immediate notification with title "Waterline is high" and body "Your Waterline is high — drink water to return to center", reusing the shared `WATER_REMINDER` category with "Log Water" and "Dismiss" actions
  - `checkPacingWarning(for:addedEstimate:)` — new function in both `ActiveSessionView` and `HomeView` that computes waterline before the drink (current minus just-added estimate) and after (current), comparing against `warningThreshold` to detect threshold crossing
  - Wired into all three drink logging paths in both views: preset chip tap (`logPreset`), drink sheet confirmation (`LogDrinkView.onLogged` callback), and `LogDrinkView` callback now passes `standardDrinkEstimate` via `(Double) -> Void` signature
  - Only fires once per threshold crossing — subsequent drinks while already above threshold do not re-trigger
- Files changed:
  - `Waterline/ReminderService.swift` (modified — added `schedulePacingWarning()` static method)
  - `Waterline/ActiveSessionView.swift` (modified — added `checkPacingWarning()`, wired into `logPreset` and `LogDrinkView` callback)
  - `Waterline/HomeView.swift` (modified — added `checkPacingWarning()`, wired into `logPreset` and `LogDrinkView` callback)
  - `Waterline/LogDrinkView.swift` (modified — changed `onLogged` from `() -> Void` to `(Double) -> Void` to pass `adjustedEstimate`)
- **Learnings:**
  - Threshold crossing detection requires knowing the waterline value before and after the drink log. Since the entry is already inserted when the callback fires, computing `previousValue = currentValue - addedEstimate` is the cleanest approach — no need to reorder insertion logic
  - Changing `LogDrinkView.onLogged` from `() -> Void` to `(Double) -> Void` is a minimal API change that enables all callers to receive the logged estimate for downstream checks (pacing warning, future analytics)
  - The pacing warning notification reuses the existing `WATER_REMINDER` category, so "Log Water" action handling in `NotificationDelegate` works automatically — no new category registration needed
  - Using unique `UUID().uuidString` suffixed identifiers for pacing warning notifications prevents the system from deduplicating multiple warnings across different sessions
---

## 2026-02-13 - US-022
- What was implemented:
  - SessionSummaryView upgraded with complete acceptance criteria: total alcoholic drinks (count + standard drink total), total water entries (count + total volume in oz), session duration, pacing adherence percentage, final waterline value
  - Pacing adherence algorithm fixed: replaced simplified `totalWater / totalDrinks` with chunk-based N-drink rule algorithm that walks entries in timestamp order, tracking drink groups of size N and counting water opportunities logged vs due
  - Pacing adherence now always displayed (live-computed from entries) rather than only when `computedSummary` exists — consistent display whether session was ended properly or not
  - `@Query private var users: [User]` added to read `waterEveryNDrinks` from user settings for pacing adherence calculation
  - Total water volume display: "3 (24 oz)" format showing both count and cumulative oz
  - "Done" toolbar button added using `@Environment(\.dismiss)` to pop back to HomeView
  - `recomputeSummary()` now uses the same chunk-based `computePacingAdherence()` method for consistency
  - Timeline list with chronological entries, edit/delete with summary recomputation — all pre-existing from US-017
- Files changed:
  - `Waterline/SessionSummaryView.swift` (modified — added users query, dismiss environment, water volume, chunk-based pacing, Done button)
- **Learnings:**
  - The original pacing adherence calculation (`totalWater / expectedWaters`) was a rough approximation that didn't match the PRD's "percentage of times water was logged within the N-drink rule" — the chunk-based algorithm properly tracks drink groups and water opportunities
  - `@Environment(\.dismiss)` with a toolbar "Done" button is the standard SwiftUI pattern for returning from a detail view pushed onto a NavigationStack — it pops the view off the stack
  - Computing pacing adherence live from entries (rather than only from `computedSummary`) ensures the value is always visible, even for sessions that were ended without proper summary computation
  - Adding `@Query private var users: [User]` follows the established codebase pattern (used in ActiveSessionView, HomeView) for accessing user settings from any view
---

## 2026-02-13 - US-024
- What was implemented:
  - `SettingsView` with 5 sections: Reminders (time-based toggle + interval picker, per-drink water frequency stepper), Waterline (warning threshold stepper), Defaults (water amount stepper, oz/ml segmented picker), Presets (NavigationLink to existing `PresetsListView` with preset count badge), Account (sign out with confirmation, delete account with destructive confirmation dialog)
  - All settings changes save immediately to SwiftData via `Binding(get:set:)` pattern that mutates `user.settings` directly and calls `modelContext.save()`
  - Delete account flow: cascade-deletes all SwiftData entities (presets → log entries → sessions → user), cancels active reminders, resets `hasCompletedOnboarding` UserDefaults flag, calls `authManager.signOut()` to return to onboarding
  - `HomeView` updated to accept `authManager: AuthenticationManager` parameter, forwarded to `SettingsView` for sign-out/delete account
  - `RootView` updated to pass `authManager` to `HomeView`
  - Gear icon in HomeView toolbar now navigates to `SettingsView` (previously went directly to `PresetsListView`)
  - Convex `deleteUser` mutation added to cascade-delete all remote user data (presets → log entries → sessions → user) by `appleUserId`
  - `ConvexService.deleteUser(appleUserId:)` Swift method added
- Files changed:
  - `Waterline/SettingsView.swift` (new) — full settings screen with all 5 sections
  - `Waterline/HomeView.swift` (modified — added `authManager` parameter, updated toolbar to navigate to SettingsView, updated preview)
  - `Waterline/ContentView.swift` (modified — RootView passes `authManager` to HomeView)
  - `Waterline/ConvexService.swift` (modified — added `deleteUser(appleUserId:)` method)
  - `convex/mutations.ts` (modified — added `deleteUser` mutation with cascade delete)
- **Learnings:**
  - `Binding(get:set:)` with direct `user?.settings.field = newValue` + `modelContext.save()` is the cleanest pattern for settings that save immediately — no need for `@State` local copies since SwiftData's `@Query` handles reactivity
  - Passing `AuthenticationManager` through the view hierarchy (RootView → HomeView → SettingsView) is necessary because auth state drives top-level navigation and can't be reconstructed from SwiftData alone — the Keychain credential store and auth state machine are app-level concerns
  - `UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")` must be called during account deletion to ensure the user goes through full onboarding again, not just the sign-in screen — `@AppStorage` reads from the same backing store
  - Delete account must delete child entities (presets, log entries) before parent entities (sessions, user) even though SwiftData `@Relationship(deleteRule: .cascade)` should handle it — explicit deletion is safer and avoids relying on cascade timing during batch deletes
---

## 2026-02-13 - US-026
- What was implemented:
  - `SyncService` (`@Observable @MainActor`) with `NWPathMonitor` for network connectivity detection, background sync queue that queries SwiftData for `needsSync == true` items, and pushes to Convex via `ConvexService`
  - `SyncStatusIndicator` view — subtle cloud icon with four states: idle (checkmark.icloud), syncing (animated arrow.triangle.2.circlepath.icloud), offline (icloud.slash), error (exclamationmark.icloud) with pending count badge
  - `SyncStatus` enum with `.idle`, `.syncing`, `.offline`, `.error(String)` cases
  - `needsSync: Bool` field added to `Session`, `LogEntry`, and `DrinkPreset` SwiftData models (default `true`)
  - `syncService.triggerSync()` wired into all data mutation points: log water, log drink (sheet), log preset, delete entries, start session
  - Sync indicator added to `HomeView` toolbar (leading) and `ActiveSessionView` toolbar (trailing)
  - `SyncService` threaded through view hierarchy: `WaterlineApp` → `RootView` → `HomeView` → `ActiveSessionView`
  - Removed old placeholder `syncSessionToConvex()` fire-and-forget stub from `HomeView`
  - Last-write-wins conflict resolution via Convex upsert mutations with `existingId`
  - All previews updated for new `syncService` parameter
- Files changed:
  - `Waterline/SyncService.swift` (new) — offline-first sync engine with NWPathMonitor
  - `Waterline/SyncStatusIndicator.swift` (new) — subtle cloud icon sync status view
  - `Waterline/Models.swift` (modified — added `needsSync: Bool` to Session, LogEntry, DrinkPreset)
  - `Waterline/WaterlineApp.swift` (modified — creates SyncService, passes to RootView, starts on appear)
  - `Waterline/ContentView.swift` (modified — RootView accepts and passes syncService)
  - `Waterline/HomeView.swift` (modified — accepts syncService, sync indicator in toolbar, triggerSync after mutations, removed old placeholder)
  - `Waterline/ActiveSessionView.swift` (modified — accepts syncService, sync indicator in toolbar, triggerSync after mutations)
- **Learnings:**
  - `NWPathMonitor` must start on a non-main `DispatchQueue` — using `DispatchQueue(label: ...)` for the monitor queue, then dispatching UI state updates back to `@MainActor` via `Task { @MainActor in ... }`
  - SwiftData `#Predicate` works well for filtering `needsSync == true` — the `$0.needsSync` syntax resolves to the stored Bool property
  - Creating a fresh `ModelContext(modelContainer)` in the sync engine avoids conflicts with the view's `@Environment(\.modelContext)` — each context operates independently
  - `@State private var syncService: SyncService` in `WaterlineApp` requires `_syncService = State(initialValue:)` initialization in `init()` since the property wrapper can't be assigned directly before `self` is available
  - `symbolEffect(.pulse, isActive:)` provides a nice animated indicator for the syncing state on SF Symbols without needing a custom animation
  - XcodeGen auto-includes new `.swift` files from the `path: Waterline` source glob, but `xcodegen generate` must be re-run for the Xcode project to pick them up
---

