# PRD: Waterline MVP — iOS Pacing Companion

## Overview
Waterline is a native Swift/SwiftUI iOS + Apple Watch pacing companion for alcohol consumption. It helps users drink less by inserting structured water breaks during "Night Out" sessions. The core mechanic is a Waterline indicator that rises with alcoholic drinks (by standard drink estimate) and lowers with water (-1). The app is minimalist, data-forward, and calm-tech — prioritizing clarity, restraint, and corrective nudges over gamification.

This is a greenfield native Swift project targeting iOS 17+ and watchOS 10+.

## Goals
- Let users start/end bounded drinking sessions and log drinks/water in <2 taps from any surface (phone, watch, widget, Live Activity)
- Reduce total alcoholic drinks per session via pacing friction and water break nudges
- Provide a clear Waterline balance indicator that updates in real-time across all surfaces
- Deliver configurable time-based and per-drink reminders with actionable notifications
- Store data locally (SwiftData) with Convex cloud sync for persistence
- Show a post-session summary with timeline, counts, and pacing adherence
- Validate retention and engagement through session usage patterns

## Quality Gates

These checks must pass for every user story:

- `xcodebuild build` — Project compiles without errors
- `swift test` — All Swift Testing (`@Test`) tests pass
- Verify in iOS Simulator that the feature works as specified

For watch/widget/Live Activity stories:
- Build and verify on watchOS Simulator or widget preview as applicable

## User Stories

### US-001: Initialize Xcode project with all targets
As a developer, I want a properly structured Xcode project so that all targets are configured from the start.

**Acceptance Criteria:**
- [ ] New Xcode project named "Waterline" with bundle ID `com.waterline.app`
- [ ] SwiftUI App target (iOS 17+)
- [ ] watchOS companion app target (watchOS 10+)
- [ ] WidgetKit extension target
- [ ] App Intent extension target (for interactive widgets/Live Activity actions)
- [ ] Project builds successfully for all targets
- [ ] Folder structure: `Waterline/`, `WaterlineWatch/`, `WaterlineWidgets/`, `WaterlineIntents/`, `WaterlineTests/`
- [ ] Swift Testing framework configured in test target

### US-002: Set up SwiftData models
As a developer, I want the core data models defined in SwiftData so that all features can persist data locally.

**Acceptance Criteria:**
- [ ] `User` model: `id`, `appleUserId`, `createdAt`, `settings` (embedded)
- [ ] `UserSettings` model: `waterEveryNDrinks` (Int, default 1), `timeRemindersEnabled` (Bool), `timeReminderIntervalMinutes` (Int, default 20), `warningThreshold` (Int, default 2), `defaultWaterAmountOz` (Int, default 8), `units` (enum: oz/ml)
- [ ] `Session` model: `id`, `userId`, `startTime`, `endTime` (optional), `isActive` (Bool), `computedSummary` (optional)
- [ ] `LogEntry` model: `id`, `sessionId`, `timestamp`, `type` (enum: alcohol/water), `alcoholMeta` (optional: drinkType, sizeOz, abv, standardDrinkEstimate, presetId), `waterMeta` (optional: amountOz), `source` (enum: phone/watch/widget/liveActivity)
- [ ] `DrinkPreset` model: `id`, `userId`, `name`, `drinkType` (enum: beer/wine/liquor/cocktail), `sizeOz`, `abv` (optional), `standardDrinkEstimate` (Double)
- [ ] All models use `@Model` macro and relationships are properly defined
- [ ] Unit tests verify model creation, relationships, and defaults

### US-003: Set up Convex backend schema and sync foundation
As a developer, I want Convex configured with matching schema so that data can sync to the cloud.

**Acceptance Criteria:**
- [ ] Convex project initialized with `npx convex init`
- [ ] Convex schema defined matching SwiftData models: `users`, `sessions`, `logEntries`, `drinkPresets` tables
- [ ] Convex auth provider configured for Sign in with Apple (use built-in if available, otherwise custom function that accepts Apple identity token and creates/verifies user)
- [ ] If Convex Swift SDK exists and is usable: integrate it; otherwise use Convex HTTP API via `URLSession` async/await
- [ ] Basic CRUD mutation functions: `createUser`, `upsertSession`, `addLogEntry`, `deleteLogEntry`, `upsertDrinkPreset`
- [ ] Basic query functions: `getActiveSession`, `getSessionLogs`, `getUserPresets`
- [ ] Convex deployment works (`npx convex dev` runs without errors)
- [ ] Swift service layer (`ConvexService`) that wraps API calls with async/await
- [ ] Tests verify Convex functions work (can be integration tests or function-level tests)

### US-004: Sign in with Apple authentication flow
As a user, I want to sign in with my Apple ID so that my data is tied to my account.

**Acceptance Criteria:**
- [ ] Sign in with Apple button on launch/onboarding screen using `SignInWithAppleButton`
- [ ] On successful Apple auth, identity token sent to Convex to create/verify user
- [ ] User record created in both SwiftData (local) and Convex (remote) on first login
- [ ] Auth state persisted locally — user stays signed in across app launches
- [ ] If Convex auth provider supports Apple natively, use that; otherwise custom token exchange via Convex function
- [ ] Error handling: show alert on auth failure with retry option
- [ ] Tests verify auth state management and token handling

### US-005: Onboarding flow — welcome and guardrail screens
As a new user, I want a brief onboarding that explains what Waterline does and sets expectations.

**Acceptance Criteria:**
- [ ] Welcome screen: "Waterline helps you pace and drink less by adding water breaks."
- [ ] Guardrail screen: "This is a pacing tool. It does not estimate intoxication or guarantee how you'll feel tomorrow."
- [ ] Screens use SwiftUI with calm, minimalist styling
- [ ] Navigation: Welcome → Guardrail → Sign in with Apple → Configure defaults
- [ ] Onboarding only shows once (persisted flag)
- [ ] Verified in Simulator: screens display correctly, navigation works

### US-006: Onboarding flow — configure defaults
As a new user, I want to set my pacing preferences during onboarding so the app works for me from the first session.

**Acceptance Criteria:**
- [ ] Configuration screen with: water every N drinks (stepper, min 1, default 1), time-based reminders toggle + interval picker (10/15/20/30/45/60 min), warning threshold (stepper, min 1, default 2), units (oz/ml toggle)
- [ ] Values saved to `UserSettings` in SwiftData
- [ ] "Done" button completes onboarding and navigates to Home
- [ ] Request notification permission with explanation before asking ("Waterline sends gentle reminders to drink water during your session")
- [ ] Tests verify settings are persisted correctly

### US-007: Home screen — no active session state
As a user, I want to see a clear home screen that lets me start a session or view past sessions.

**Acceptance Criteria:**
- [ ] Primary CTA: "Start Session" button (prominent)
- [ ] Secondary: Settings icon/button, Past Sessions list (last 5 sessions with date, duration, drink/water counts)
- [ ] If no past sessions, show empty state message
- [ ] Tapping a past session navigates to summary view
- [ ] Verified in Simulator

### US-008: Home screen — active session state
As a user returning to the app with an active session, I want to immediately see my session status.

**Acceptance Criteria:**
- [ ] If active session exists: show Waterline indicator, current counts (drinks/water), and "View Session" CTA
- [ ] Quick-add buttons visible: "+ Drink" and "+ Water"
- [ ] Session auto-recovery: if app was killed and session is still active, this state appears on relaunch
- [ ] Verified in Simulator

### US-009: Start session
As a user, I want to start a "Night Out" session so I can begin tracking.

**Acceptance Criteria:**
- [ ] Tapping "Start Session" creates a new `Session` in SwiftData with `startTime = now`, `isActive = true`
- [ ] Only one active session allowed — if one exists, navigate to it instead
- [ ] Session syncs to Convex in background
- [ ] Navigates to Active Session screen
- [ ] Live Activity starts (handled in separate story, but session creation triggers it)
- [ ] Tests verify session creation and single-active constraint

### US-010: Active session screen — Waterline indicator
As a user, I want to see my current Waterline balance prominently during a session.

**Acceptance Criteria:**
- [ ] Waterline indicator displays as a vertical gauge/bar with a center line representing "balanced"
- [ ] Indicator shows current `waterlineValue` visually: above center = over-paced, below center = buffered
- [ ] Normal state: neutral/calm accent color
- [ ] Warning state: when `waterlineValue >= warningThreshold`, indicator turns red/amber with text "Drink water to return to center"
- [ ] Indicator animates smoothly when value changes
- [ ] Verified in Simulator: indicator renders correctly at values -3, 0, 1, 2, 3, 5

### US-011: Active session screen — counters and reminder status
As a user, I want to see my drink/water counts and when my next reminder is due.

**Acceptance Criteria:**
- [ ] Display: total alcoholic drink count, total water count
- [ ] Display: "Water due in: X drinks" (based on `alcoholCountSinceLastWater` vs `waterEveryNDrinks`)
- [ ] Display: "Next reminder: X:XX" (countdown to next time-based reminder, if enabled)
- [ ] Counters update immediately when a log is added
- [ ] Verified in Simulator

### US-012: Log alcoholic drink — full flow
As a user, I want to log an alcoholic drink with type and size so the Waterline updates accurately.

**Acceptance Criteria:**
- [ ] Drink type picker: beer, wine, liquor, cocktail
- [ ] Size presets per type (e.g., beer: 12oz/16oz/pint; wine: 5oz/glass; liquor: 1.5oz/double 3oz; cocktail: standard/strong)
- [ ] Each preset maps to a `standardDrinkEstimate` (Double) — e.g., 12oz beer = 1.0, double whiskey = 2.0
- [ ] User can see and optionally adjust the `standardDrinkEstimate` before confirming
- [ ] On confirm: `LogEntry` created with `type: .alcohol`, `alcoholMeta` populated, `source: .phone`
- [ ] Waterline value increases by `standardDrinkEstimate` (rounded or fractional as stored)
- [ ] `alcoholCountSinceLastWater` incremented by 1
- [ ] If `alcoholCountSinceLastWater >= waterEveryNDrinks`: trigger per-drink water reminder
- [ ] If `waterlineValue >= warningThreshold`: show warning state
- [ ] Log syncs to Convex in background
- [ ] Tests verify Waterline calculation, reminder trigger, warning state

### US-013: Log water
As a user, I want to log water quickly so the Waterline decreases.

**Acceptance Criteria:**
- [ ] Quick "+" Water button on active session screen
- [ ] Default amount from user settings (e.g., 8oz)
- [ ] On tap: `LogEntry` created with `type: .water`, `waterMeta.amountOz` set, `source: .phone`
- [ ] Waterline value decreases by 1
- [ ] `alcoholCountSinceLastWater` resets to 0
- [ ] If `waterlineValue` drops below `warningThreshold`: clear warning state
- [ ] Log syncs to Convex in background
- [ ] Tests verify Waterline calculation and state reset

### US-014: Quick-add buttons on active session
As a user, I want prominent quick-add buttons for drink and water so logging takes <2 taps.

**Acceptance Criteria:**
- [ ] Bottom of active session screen: two large tappable buttons — "+ Drink" and "+ Water"
- [ ] "+ Water" immediately logs water with defaults (single tap)
- [ ] "+ Drink" opens drink type/size picker (second tap to confirm)
- [ ] Buttons are large enough for easy tapping (minimum 44pt tap target)
- [ ] Haptic feedback on tap
- [ ] Verified in Simulator

### US-015: Drink presets — create and manage
As a user, I want to save custom drink presets so I can log my regular drinks with one tap.

**Acceptance Criteria:**
- [ ] Settings screen section: "Quick Drinks" / "Presets"
- [ ] "Add Preset" flow: name, drink type, size, optional ABV, standardDrinkEstimate (user can set custom value)
- [ ] Presets saved as `DrinkPreset` in SwiftData and synced to Convex
- [ ] Presets appear as chips/buttons on active session screen above the quick-add buttons
- [ ] Tapping a preset logs that drink immediately (single tap)
- [ ] Edit and delete presets from settings
- [ ] Tests verify preset CRUD and quick-log behavior

### US-016: Drink presets — default presets on first launch
As a new user, I want sensible default presets so I can start logging immediately.

**Acceptance Criteria:**
- [ ] On first launch after onboarding, create default presets: "Beer" (12oz, 1.0 std), "Glass of Wine" (5oz, 1.0 std), "Shot" (1.5oz, 1.0 std), "Cocktail" (1 std), "Double" (3oz, 2.0 std)
- [ ] Defaults are editable and deletable by user
- [ ] Tests verify default presets are created

### US-017: Edit and delete log entries
As a user, I want to edit or delete a log entry if I made a mistake.

**Acceptance Criteria:**
- [ ] In active session: swipe-to-delete or edit on log timeline
- [ ] In session summary: same edit/delete capability
- [ ] On edit/delete: Waterline and all counters recomputed from scratch by replaying all remaining logs in order
- [ ] Edits sync to Convex
- [ ] Tests verify recomputation is correct after delete and edit

### US-018: Time-based reminders
As a user, I want periodic reminders to drink water during my session.

**Acceptance Criteria:**
- [ ] When session starts and `timeRemindersEnabled` is true: schedule local notification repeating every `timeReminderIntervalMinutes`
- [ ] Notification content: "Time for water" (calm, non-judgmental)
- [ ] Notification actions: "Log Water" (logs water with defaults) and "Dismiss"
- [ ] "Log Water" action creates a `LogEntry` and updates Waterline
- [ ] Reminders stop when session ends
- [ ] If session inactive (no logs) for 90 minutes, stop reminders
- [ ] Tests verify scheduling and cancellation logic

### US-019: Per-drink water reminders
As a user, I want a reminder to drink water after every N alcoholic drinks.

**Acceptance Criteria:**
- [ ] When `alcoholCountSinceLastWater >= waterEveryNDrinks`: fire local notification
- [ ] Notification content: "You've had N drinks — time for water"
- [ ] Notification actions: "Log Water" and "Dismiss"
- [ ] Reminder resets when water is logged (`alcoholCountSinceLastWater` → 0)
- [ ] Tests verify trigger threshold and reset

### US-020: Pacing warning notification
As a user, I want to be warned when my Waterline crosses the warning threshold.

**Acceptance Criteria:**
- [ ] When `waterlineValue >= warningThreshold` and was previously below: fire local notification
- [ ] Notification content: "Your Waterline is high — drink water to return to center"
- [ ] Notification actions: "Log Water" and "Dismiss"
- [ ] Only fires once per threshold crossing (not on every drink while above)
- [ ] Tests verify threshold crossing detection

### US-021: End session
As a user, I want to end my session and see a summary.

**Acceptance Criteria:**
- [ ] "End Session" button on active session screen (with confirmation dialog: "End this session?")
- [ ] Sets `endTime`, `isActive = false`
- [ ] Computes summary: total drinks, total water, total standard drinks, session duration, pacing adherence (% of times water was logged within the N-drink rule)
- [ ] Stores summary in `Session.computedSummary`
- [ ] Cancels all active reminders
- [ ] Ends Live Activity
- [ ] Syncs to Convex
- [ ] Navigates to Summary screen
- [ ] Force-end works with zero logs
- [ ] Tests verify summary computation

### US-022: Session summary screen
As a user, I want to review my session after it ends.

**Acceptance Criteria:**
- [ ] Displays: total alcoholic drinks (count + standard drink total), total water entries (count + total volume), session duration, pacing adherence percentage
- [ ] Timeline list: chronological log entries with timestamps, type icons, and details
- [ ] Edit/delete log entries from summary (recomputes summary)
- [ ] Final Waterline value displayed
- [ ] "Done" button returns to Home
- [ ] Verified in Simulator

### US-023: Past sessions list
As a user, I want to view my past sessions so I can track my patterns.

**Acceptance Criteria:**
- [ ] Home screen shows last 5 sessions (date, duration, drink count, water count)
- [ ] Tapping a session opens its summary screen (read-only, no edit in past sessions for MVP)
- [ ] Empty state if no past sessions
- [ ] Verified in Simulator

### US-024: Settings screen
As a user, I want to adjust my pacing preferences and manage my account.

**Acceptance Criteria:**
- [ ] Sections: Reminders (time-based toggle + interval, per-drink N), Waterline (warning threshold), Defaults (water amount, units), Presets (manage quick drinks), Account (sign out, delete account)
- [ ] Changes save immediately to SwiftData and sync to Convex
- [ ] Delete account: removes all user data from SwiftData and Convex, signs out, returns to onboarding
- [ ] Verified in Simulator

### US-025: Abandoned session handling
As a user, I want the app to handle sessions I forgot to end.

**Acceptance Criteria:**
- [ ] If a session has been active for >12 hours: on next app launch, show prompt "Your session has been running for X hours. End it?"
- [ ] Options: "End Now" (ends with current data) and "Keep Going" (session stays active)
- [ ] Tests verify 12-hour threshold detection

### US-026: Offline-first logging and sync
As a user, I want to log drinks even without internet and have them sync later.

**Acceptance Criteria:**
- [ ] All log entries write to SwiftData first (immediate, no network required)
- [ ] Background sync queue: pending changes sync to Convex when connectivity available
- [ ] Conflict resolution: last-write-wins for edits
- [ ] Sync status indicator (subtle, non-intrusive — e.g., small cloud icon)
- [ ] Tests verify offline write and subsequent sync

### US-027: Apple Watch app — main screen with quick logging
As a user, I want to log drinks and water from my Apple Watch with minimal interaction.

**Acceptance Criteria:**
- [ ] watchOS app shows two large buttons: "+ Drink" and "+ Water" when session is active
- [ ] "+ Water" logs immediately with defaults
- [ ] "+ Drink" shows compact preset list, tapping one logs immediately
- [ ] Compact Waterline indicator and counts (drinks/water) above buttons
- [ ] If no active session: show "Start Session" button or "No active session" state
- [ ] Watch communicates with phone via WatchConnectivity framework
- [ ] Haptic confirmation on log
- [ ] Verified in watchOS Simulator

### US-028: Apple Watch app — haptic nudges
As a user, I want my watch to buzz when it's time to drink water.

**Acceptance Criteria:**
- [ ] When phone fires a water reminder (time-based or per-drink), watch receives it and plays haptic
- [ ] Haptic pattern: gentle, not alarming (e.g., `.notification` type)
- [ ] Watch shows reminder notification with "Log Water" action
- [ ] Tapping "Log Water" on watch logs water and sends to phone
- [ ] Tests verify WatchConnectivity message handling

### US-029: Apple Watch app — end session from watch
As a user, I want to end my session from the watch if my phone isn't handy.

**Acceptance Criteria:**
- [ ] "End Session" option accessible from watch (e.g., scroll down or menu)
- [ ] Confirmation prompt on watch
- [ ] Ends session on phone via WatchConnectivity
- [ ] Watch updates to "no active session" state
- [ ] Verified in watchOS Simulator

### US-030: Lock Screen widget
As a user, I want to glance at my Waterline status on my Lock Screen.

**Acceptance Criteria:**
- [ ] Lock Screen widget (WidgetKit, accessory family)
- [ ] Shows: simplified Waterline indicator, drink/water counts
- [ ] If interactive (iOS 17+): "+ Drink" and "+ Water" buttons via App Intents
- [ ] Tapping buttons logs with defaults without opening the app
- [ ] Widget updates when logs are added (via WidgetKit timeline reload)
- [ ] When no active session: shows "No Session" state
- [ ] Verified in Simulator widget preview

### US-031: Home Screen widget
As a user, I want a Home Screen widget to see session status and quick-log.

**Acceptance Criteria:**
- [ ] Small widget: Waterline indicator + quick-add buttons
- [ ] Medium widget: Waterline + counts + next reminder countdown
- [ ] Large widget: Waterline + counts + recent 3 log entries + quick-add
- [ ] Interactive buttons via App Intents (iOS 17+)
- [ ] Widget timeline updates on log events
- [ ] When no active session: shows "Start Session" or last session summary
- [ ] Verified in Simulator widget preview

### US-032: Live Activity / Dynamic Island
As a user, I want to see my session status in the Dynamic Island and Live Activity without opening the app.

**Acceptance Criteria:**
- [ ] Live Activity starts when session starts
- [ ] Displays: Waterline value, drink count, water count, next reminder countdown
- [ ] Dynamic Island compact: Waterline indicator and counts
- [ ] Dynamic Island expanded: Waterline + counts + quick actions
- [ ] Quick actions via App Intents: "+ Drink" (logs default preset), "+ Water"
- [ ] Updates in near-real-time when logs are added
- [ ] Live Activity ends when session ends
- [ ] Uses ActivityKit with proper `ActivityAttributes` and `ContentState`
- [ ] Verified in Simulator

### US-033: App Intents for interactive widgets and Live Activity
As a developer, I want App Intents defined so that widgets and Live Activity can perform actions.

**Acceptance Criteria:**
- [ ] `LogDrinkIntent`: logs an alcoholic drink (accepts optional preset ID, defaults to "standard drink" 1.0)
- [ ] `LogWaterIntent`: logs water with default amount
- [ ] `StartSessionIntent`: starts a new session
- [ ] `EndSessionIntent`: ends the active session
- [ ] Intents registered in App Intents extension
- [ ] Intents work from widgets, Live Activity, and Siri
- [ ] Tests verify intent execution and data creation

### US-034: Waterline algorithm — recompute engine
As a developer, I want a reliable algorithm that recomputes Waterline state from logs so edits are always consistent.

**Acceptance Criteria:**
- [ ] `WaterlineEngine` struct/class with method `computeState(from logs: [LogEntry]) -> WaterlineState`
- [ ] `WaterlineState`: `waterlineValue` (Double), `alcoholCountSinceLastWater` (Int), `totalAlcoholCount` (Int), `totalWaterCount` (Int), `totalStandardDrinks` (Double), `isWarning` (Bool)
- [ ] On alcohol log: `waterlineValue += standardDrinkEstimate`, `alcoholCountSinceLastWater += 1`
- [ ] On water log: `waterlineValue -= 1`, `alcoholCountSinceLastWater = 0`
- [ ] Warning: `waterlineValue >= warningThreshold`
- [ ] Engine processes logs in timestamp order
- [ ] Used everywhere state is needed (active session, summary, after edits)
- [ ] Comprehensive tests: empty logs, alternating drinks/water, doubles, edits, warning threshold crossing

### US-035: Notification permission request during onboarding
As a user, I want the app to explain why it needs notifications before asking permission.

**Acceptance Criteria:**
- [ ] After configure-defaults screen: explanation screen "Waterline sends gentle reminders to drink water during your session. Allow notifications to get pacing nudges."
- [ ] "Enable Notifications" button triggers system permission prompt
- [ ] "Skip" option — reminders will only work in-app
- [ ] Permission result stored; if denied, reminders settings show "Notifications disabled" with link to Settings
- [ ] Verified in Simulator

### US-036: Discreet notification content
As a user, I want notification text that won't be embarrassing if someone sees my Lock Screen.

**Acceptance Criteria:**
- [ ] Default notification content uses neutral language: "Time for a break" instead of "You've had 5 drinks"
- [ ] No drink counts or alcohol references in notification preview text
- [ ] Full detail visible only when notification is expanded or app is opened
- [ ] Configurable in Settings: "Discreet notifications" toggle (on by default)
- [ ] Tests verify notification content based on discreet setting

## Functional Requirements

- FR-1: The app must use Sign in with Apple as the sole authentication method
- FR-2: Only one active session may exist per user at any time
- FR-3: All log entries must persist to SwiftData immediately and sync to Convex when online
- FR-4: The Waterline value must equal the sum of all alcohol `standardDrinkEstimate` values minus the count of water logs in the session
- FR-5: Editing or deleting any log entry must trigger a full recomputation of Waterline state from all remaining ordered logs
- FR-6: Time-based reminders must fire as local notifications at the configured interval during an active session
- FR-7: Per-drink reminders must fire when `alcoholCountSinceLastWater >= waterEveryNDrinks`
- FR-8: The warning state must activate when `waterlineValue >= warningThreshold` and deactivate when it drops below
- FR-9: Quick-log from widgets, Live Activity, and Apple Watch must work without opening the main app
- FR-10: Session summary must be computed and stored when a session ends
- FR-11: Account deletion must remove all user data from both SwiftData and Convex
- FR-12: All notification content must respect the discreet notifications setting
- FR-13: Users must be able to create custom drink presets with user-defined `standardDrinkEstimate` values
- FR-14: The Apple Watch must communicate with the phone via WatchConnectivity for log sync and session state

## Non-Goals (Out of Scope)

- Hangover prediction, BAC estimation, dehydration estimation, or medical recommendations
- Food or caffeine tracking
- Next-day check-in, weekly trends/goals, long-term analytics dashboards
- Social/buddy accountability or community features
- Rideshare integration or "don't drive" CTAs
- HealthKit-based inference
- Remote push notifications (local only for MVP)
- Multi-device simultaneous editing conflict handling beyond last-write-wins
- Analytics instrumentation (deferred to post-MVP)
- Paid tier, subscriptions, or monetization features
- System theme auto-detection for the app itself

## Technical Considerations

- **Language/UI**: Swift 5.9+, SwiftUI, iOS 17+, watchOS 10+
- **Persistence**: SwiftData for local-first storage
- **Backend**: Convex (Swift SDK if available, otherwise HTTP API via URLSession async/await)
- **Auth**: Sign in with Apple → Convex auth (built-in provider preferred, custom token exchange fallback, CloudKit sync as last resort)
- **Widgets**: WidgetKit with App Intents for interactivity
- **Live Activity**: ActivityKit with `ActivityAttributes` and `ContentState`
- **Watch**: WatchConnectivity framework for phone↔watch communication
- **Notifications**: UNUserNotificationCenter for local notifications with actions
- **Testing**: Swift Testing framework (`@Test` macro, `@Suite`)
- **Architecture**: MVVM with SwiftUI's `@Observable` macro; `WaterlineEngine` as a pure computation module; service layer for Convex sync

## Success Metrics

- App compiles and runs on iOS 17 Simulator and watchOS 10 Simulator
- User can complete full journey: onboard → start session → log drinks/water → receive reminders → end session → view summary
- Waterline indicator updates correctly across all surfaces (app, widget, Live Activity, watch)
- Offline logging works and syncs when connectivity returns
- All Swift Testing tests pass
- Quick-log from any surface takes ≤2 taps

## Open Questions

1. **Convex Swift SDK availability**: Does a production-ready Convex Swift SDK exist? If not, the HTTP API fallback (US-003) applies.
2. **Live Activity update frequency**: ActivityKit has rate limits on updates (~once per second for frequent, but Apple throttles). Is near-real-time sufficient or do we need exact instant updates?
3. **Watch app as standalone vs companion-only**: Should the watch app work independently (own SwiftData store) or require phone nearby? MVP assumption: companion-only via WatchConnectivity.
4. **Fractional Waterline display**: `standardDrinkEstimate` can be fractional (e.g., 1.5). Should the Waterline indicator show decimal values (3.5) or round for display? Algorithm stores exact; display can round.