# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# iOS build (required check after every task — must pass before closing work)
xcodebuild -project Waterline.xcodeproj -scheme Waterline \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.0' \
  build 2>&1 | xcsift -f toon -w

# watchOS build
xcodebuild -project Waterline.xcodeproj -scheme WaterlineWatch \
  -destination 'generic/platform=watchOS' \
  build 2>&1 | xcsift -f toon -w

# Regenerate Xcode project from project.yml
xcodegen generate
```

Document the build pass/fail outcome in your final response.

## Project Generation (XcodeGen)

The `.xcodeproj` is generated from `project.yml`. After running `xcodegen generate`:
- Verify `.entitlements` files have actual properties (not empty `<dict/>`). The `properties` key under `entitlements` in project.yml is what populates them.
- Verify the "Embed Watch Content" build phase exists on the iOS target.
- watchOS targets must use `platform: watchOS` (not `supportedDestinations`).

## Architecture

**Waterline** is an alcohol pacing companion app. Users start a drinking session, log drinks and water, and a "waterline" metric tracks their pacing. The app runs on iOS + watchOS with Live Activities, widgets, and a Convex cloud backend.

### Targets & Shared Code

| Target | Type | Purpose |
|--------|------|---------|
| `Waterline` | iOS app | Main app with all views, services, managers |
| `WaterlineWatch` | watchOS app | Companion with gauge, quick-add buttons, preset picker |
| `WaterlineWidgets` | App extension | Home screen widget + Live Activity (lock screen & Dynamic Island) |
| `WaterlineIntents` | ExtensionKit extension | App Intents for Siri shortcuts and widget button actions |

**Shared files** (compiled into Widgets + Intents targets via `project.yml` source paths, NOT via a framework):
- `Models.swift` — SwiftData models (`User`, `Session`, `LogEntry`, `DrinkPreset`) and enums
- `WaterlineEngine.swift` — Pure computation, no UI/persistence dependencies
- `SessionActivityAttributes.swift` — ActivityKit attributes

### Core Computation

`WaterlineEngine` is a stateless, pure-function module. It replays `LogEntry` arrays to compute `WaterlineState` (waterline value, drink/water counts, warning status). Used by every target. All state derivation flows through it — never duplicate waterline math elsewhere.

### Cross-Process IPC

Widget/Intent extensions run in separate processes and **cannot** update Live Activities directly (Swift module-qualified type mismatch with `Activity<T>.activities`).

**Solution**: `LiveActivityBridge` in `Models.swift`:
1. Intent writes computed state to App Group UserDefaults
2. Posts Darwin notification
3. Main app's observer (set up in `WaterlineApp.init()`) reads state and calls `LiveActivityManager.updateActivity()`

### Watch ↔ Phone Sync

- **iOS side**: `WatchConnectivityManager` — sends session state via `updateApplicationContext()`, receives commands (`logWater`, `logDrink`, `startSession`, `endSession`)
- **watchOS side**: `WatchSessionManager` — observes state, sends commands via `sendMessage()`
- **Command handlers**: All in `WaterlineApp.swift` static methods (`handleWatchLogWater`, etc.)

### Data & Sync

- **Local**: SwiftData with App Group container (`group.com.waterline.app.shared`) for cross-process access
- **Remote**: Convex cloud (`convex/` directory) — `SyncService` pushes `needsSync=true` records via `ConvexService` HTTP client
- **Auth**: Sign In with Apple → `AuthenticationManager` → Keychain storage

### Notification System

`ReminderService` handles three reminder types: time-based (repeating interval), per-drink (fires when alcohol count since last water >= threshold), and pacing warnings (waterline crosses threshold). `NotificationDelegate` handles notification actions.

## Design System

Swiss-modernist instrument-panel aesthetic defined in `WaterlineDesign.swift`. Monochrome, typography-first, flat, square-cornered, no SF Symbols.

**Critical**: Watch and Widget targets cannot access `WaterlineDesign.swift`. Those targets define colors via local `private extension Color` blocks. Use `Color.memberName` syntax (not shorthand `.memberName`) due to SwiftUI's `ShapeStyle` generic constraint.

## Convex Backend

Schema in `convex/schema.ts`. Mutations in `convex/mutations.ts`, queries in `convex/queries.ts`. Run `npx convex dev` for local development. Deployment URL is hardcoded in `WaterlineApp.swift`.

## Swift Version

Swift 6.0 with strict concurrency. `@MainActor` annotations are used throughout; watch for `Sendable` conformance requirements when passing data across isolation boundaries.
