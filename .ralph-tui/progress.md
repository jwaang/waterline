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

