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

### Auth Pattern (AuthenticationManager.swift)
- `AuthenticationManager` is `@Observable @MainActor` — drives SwiftUI reactive auth state
- Uses `AuthCredentialStore` protocol for storage injection (Keychain in prod, in-memory for tests)
- `KeychainStore` is the production implementation; `InMemoryCredentialStore` for unit tests
- Auth flow: `SignInWithAppleButton` → `handleAuthorization()` → Keychain + SwiftData + Convex sync
- `restoreSession()` called on app launch to hydrate from Keychain
- Convex sync is fire-and-forget (non-fatal failure) — local SwiftData is authoritative

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

