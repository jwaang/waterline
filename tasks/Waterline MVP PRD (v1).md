Waterline MVP PRD (v1)

1. Product summary
   Waterline is an iOS + Apple Watch pacing companion for alcohol consumption. It helps users drink less by inserting structured water breaks and pacing friction during a “Night Out” session. The core mechanic is a simple “Waterline” indicator that rises with alcoholic drinks (+1) and lowers with water (-1). The UI is minimalist, data-forward, and calm-tech: it prioritizes clarity, restraint, and corrective nudges rather than gamification.

2. Problem statement
   Many people want to limit alcohol intake during social drinking but lose track of pacing in the moment. Users also want a simple mechanism to interleave water breaks, which can reduce drinking velocity and improve next-day subjective wellbeing (without making medical promises). Existing habit and hydration apps do not focus on the “night out” context, fast logging, watch-first nudges, and a single balance indicator.

3. Goals (MVP)
   Primary goals (user-facing):

* Reduce total alcoholic drinks per session by creating pacing friction and water breaks.
* Reduce drinking velocity (pace slower).
* Provide a simple session summary users can review.

Product goals (business/validation):

* Validate retention: users return and run sessions repeatedly across weekends/occasions.
* Validate engagement: users log consistently during sessions, respond to nudges, and complete sessions.
* Prepare for future monetization: measure “upgrade intent” signals despite v1 being free.

4. Non-goals (explicitly out of scope for MVP)

* Hangover prediction, BAC estimation, dehydration estimation, or medical recommendations.
* Food/caffeine tracking.
* Next-day check-in, weekly trends/goals, long-term analytics dashboards.
* Social/buddy accountability, community features.
* Rideshare integration / “don’t drive” CTA (user requested exclude for MVP).
* HealthKit-based inference.

5. Target platforms and minimum OS assumptions
   Required MVP surfaces:

* iPhone app (SwiftUI)
* Apple Watch app (watchOS)
* Widgets: Lock Screen + Home Screen
* Live Activity / Dynamic Island

Recommended minimum versions for interactive quick logging:

* iOS 17+ (for interactive widgets and modern ActivityKit patterns)
* watchOS 10+ (for modern SwiftUI watch patterns)

If you need broader OS support, quick logging from widgets becomes “tap → open app to log” rather than true one-tap logging.

6. Primary persona
   “Intentional drinker”: someone who drinks alcohol (light to heavy) and wants to limit intake. They care about pacing, want to insert water breaks, and want lightweight tracking without judgment. The persona spans from “2 drinks at dinner” to “20 drinks on a heavy night,” so the system must scale without assuming a fixed range.

7. Core MVP user journey (happy path)

1) Onboard (Sign in with Apple)
2) Configure defaults: water every N drinks, reminder intervals, standard drink preferences
3) Start “Night Out” session
4) Log alcoholic drinks and water quickly (phone or watch)
5) Receive nudges (time-based and/or per-drink)
6) See Waterline indicator move toward/away from center
7) End session
8) Session summary (counts, pacing, timeline)

8. Key product concepts
   A) Session
   A bounded time period (“Night Out”) with logs and reminders. Users can run multiple sessions per week.

B) Log entry
A timestamped event: either an alcoholic drink (with type/size/ABV mapped to “standard drinks”) or water.

C) Standard drinks
MVP uses standard drink sizing to normalize beer/wine/liquor. Users can select drink type + size; the app maps it to a “standard drink count” used for reporting (and optionally for future weighting). For Waterline movement, MVP keeps it simple: +1 per alcoholic log entry regardless of ABV (see “Open questions” for whether to weight).

D) Waterline indicator
A neutral “balance” meter, not physiological. It starts centered at session start.

* Alcoholic drink: Waterline +1
* Water: Waterline -1
  It is visually framed as “balance,” “neutrality,” or “center,” not “safe/unsafe.”

E) Nudges
Two configurable nudge systems:

* Time-based reminders (every X minutes)
* Per-drink reminders (water every N alcoholic drinks)
  Users can enable either or both.

9. Functional requirements

9.1 Authentication and user account

* Sign in with Apple required for MVP.
* Create a user record in Convex on first login.
* Minimal profile: appleUserId (or stable identifier), createdAt, settings.

9.2 Session management

* Start session: creates a new session record with startTime, initial state, active flag.
* Only one active session at a time per user.
* End session: sets endTime, computes summary stats, deactivates reminders/live activity.
* Resume session: if app relaunches and session active, return user to session view.
* Session auto-recovery: if the app crashes, the active session persists.

Edge cases:

* Force end: user can end session even with zero logs.
* Abandoned session: if a session remains active beyond a configurable duration (default 12 hours), prompt user to end or auto-end (MVP can simply prompt).

9.3 Logging (manual + quick presets)
Manual logging (in-app):

* Add Alcoholic Drink: choose type (beer/wine/liquor/cocktail), choose size (common presets), optional ABV (optional in MVP), add note (exclude in MVP unless you want it).
* Add Water: choose amount (defaults like 8 oz / 250 ml; quick add).

Quick logging:

* Two primary quick actions: “+ Drink” and “+ Water”
* Quick actions available on:

  * Apple Watch app (big tappable buttons)
  * iPhone app session screen (bottom actions)
  * Widgets / Live Activity (if interactive; otherwise deep link)

Presets:

* Users can create “Quick Drinks” presets (e.g., “12oz beer,” “5oz wine,” “vodka soda”).
* Presets appear as one-tap options in session logging UI and watch.

Editing:

* Users can delete or edit a log entry during an active session and in summary view.
* Any edit recomputes Waterline and summary stats.

9.4 Waterline indicator behavior and UI states

* Waterline value is an integer that can go negative.
* Visual:

  * Center line/band indicates “neutral/balanced.”
  * Above center indicates “over pace / needs water break.”
  * Below center indicates “buffered/recovered” (language must remain neutral).
* State styling:

  * Normal: neutral accent
  * Warning threshold: when Waterline ≥ user-defined limit (or computed limit), show red warning state and “Drink water to return to center.”

MVP thresholds:

* Default warning threshold: Waterline ≥ 2 (configurable).
* Additional warning: if alcoholic count since last water ≥ N (based on rule), show warning.

9.5 Reminders and notification logic
User settings:

* Time-based reminders: enable + interval (e.g., 20 minutes)
* Per-drink reminders: water every N alcoholic drinks (default N=1 or N=2; you chose “water every N drinks”)
* Quiet constraints: optional “do not remind after end session” (default), optionally “stop reminders if session inactive for 90 minutes without logs.”

Reminder delivery surfaces:

* Apple Watch haptics (primary)
* iPhone notifications (secondary)
* In-app banners (when app open)

Reminder types:

* “Water Reminder” (time-based)
* “Water Reminder” (per-drink triggered when alcoholicCountSinceLastWater reaches N)
* “Pacing Warning” (when Waterline crosses threshold)

Interaction:

* Notification actions: “Log Water” and “Dismiss”
* If user taps “Log Water,” it adds a water log entry with default amount and updates Waterline.

9.6 Widgets (Lock Screen + Home Screen)
Lock Screen widget:

* Shows current session status (active/inactive).
* Shows Waterline position (simplified bar/line), counts (Drinks, Water), and next reminder time.
* If interactive: buttons “+ Drink” and “+ Water.”
* If not interactive: tapping opens app to quick-log screen.

Home Screen widget:

* Small/medium/large variants:

  * Small: Waterline + quick add
  * Medium: Waterline + counts + next reminder
  * Large: Waterline + recent logs + quick add

9.7 Live Activity / Dynamic Island
When a session is active:

* Live Activity displays Waterline, counts, next reminder countdown.
* Provides quick actions: +Drink, +Water (if interactive).
* Updates when a log is added or reminder triggers.

9.8 Apple Watch app
Primary watch experience:

* Big two-button quick log: +Drink, +Water
* A compact Waterline indicator and counts.
* Optional “End Session” on watch.
* Haptic nudges aligned with reminder triggers.

9.9 Session summary (end-of-session)
After ending:

* Summary contents:

  * Total alcoholic drinks (count and optionally standard drink estimate)
  * Total water entries (count and optionally total volume)
  * Session duration
  * Timeline list of logs (time-ordered)
  * “Pacing adherence” summary: e.g., % times user logged water within the rule
* No “hangover outcome” in MVP.

10. UX structure (screens)

10.1 Onboarding

* Welcome: “Waterline helps you pace and drink less by adding water breaks.”
* Guardrail copy: “This is a pacing tool. It does not estimate intoxication or guarantee how you’ll feel tomorrow.”
* Sign in with Apple
* Configure:

  * Water every N drinks (default 1 or 2)
  * Time-based reminders toggle + interval
  * Warning threshold toggle/value
  * Units (oz/ml)

10.2 Home

* If no active session:

  * Primary CTA: Start Session
  * Secondary: Settings, Past Sessions list (optional for MVP; at minimum show last 5 sessions)
* If active session:

  * Show Waterline instrument and quick log actions
  * CTA: View Session

10.3 Active Session

* Top: Waterline indicator with center band and warning state
* Middle: Counters (Drinks, Water), and “Water due in: X” or “Next reminder: X”
* Bottom: Quick add buttons and preset chips
* Secondary actions: Edit last entry, End session

10.4 Quick Log (optional dedicated)

* If you want faster flows: a dedicated “Quick Log” sheet with preset buttons and two large actions.

10.5 Summary

* Visual: final Waterline range shown, plus totals
* Timeline list with edit/delete
* CTA: Done → Home

10.6 Settings

* Reminder settings
* Water every N drinks
* Warning threshold
* Default water amount
* Presets management
* Account: Sign out / delete account (delete is recommended for privacy compliance)

11. Data model (Convex + local cache)

Core tables/collections:
User

* id
* appleUserId
* createdAt
* settings (json)

Settings (embedded or separate)

* waterEveryNDrinks: Int
* timeRemindersEnabled: Bool
* timeReminderIntervalMinutes: Int
* warningThreshold: Int
* defaultWaterAmount: Int (oz or ml)
* units: “oz” | “ml”
* presets: array of DrinkPreset IDs or embedded

Session

* id
* userId
* startTime
* endTime (nullable)
* isActive
* computedSummary (nullable json: totals, duration, adherence)

LogEntry

* id
* sessionId
* timestamp
* type: “alcohol” | “water”
* alcoholMeta (nullable): drinkType, size, abv(optional), standardDrinkEstimate(optional), presetId(optional)
* waterMeta (nullable): amount
* source: “phone” | “watch” | “widget” | “live_activity”

DrinkPreset

* id
* userId
* name
* drinkType
* size
* abv(optional)
* standardDrinkEstimate(optional)

Local-first requirement:

* Logs must be writable offline and sync when online.
* Conflict policy: last-write-wins for edits; avoid multi-device simultaneous edits in MVP.

12. Waterline algorithm (MVP)
    State variables during a session:

* waterlineValue: Int (starts at 0)
* alcoholCountSinceLastWater: Int
* totalAlcoholCount: Int
* totalWaterCount: Int

On add alcohol:

* waterlineValue += 1
* alcoholCountSinceLastWater += 1
* if alcoholCountSinceLastWater >= N: trigger per-drink water reminder
* if waterlineValue >= warningThreshold: show warning state

On add water:

* waterlineValue -= 1
* alcoholCountSinceLastWater = 0
* if waterlineValue drops below warningThreshold: clear warning state

Recompute strategy:

* Whenever logs are edited/deleted, recompute state from ordered logs to ensure correctness.

13. Analytics and success metrics (instrumentation)

Core events:

* auth_success
* onboarding_completed
* session_started
* log_added (type, source, hasPreset)
* reminder_fired (time-based vs per-drink)
* reminder_action_taken (log_water / dismiss / opened_app)
* session_ended (duration, totals)
* widget_used / live_activity_used / watch_used

MVP KPIs aligned to your validation priorities:
Retention:

* D1/D7 retention
* Weekly active users
  Engagement:
* Sessions per active user per week
* Avg logs per session
* % sessions with at least one reminder acted on
  Upgrade intent (since v1 is free):
* “Notify me when Pro launches” CTA taps (optional)
* Feature gating screen views (if you include a future “Insights” placeholder)

Note: “subscription conversion” cannot be measured in a free-only MVP without an upgrade path. The PRD recommends measuring “upgrade intent” instead.

14. Privacy, safety, and tone requirements

* Copy must remain calm and non-judgmental.
* Avoid any claim implying hangover prevention or intoxication estimation.
* Explicit framing: “pacing tool” / “self-regulation tool.”
* Data handling:

  * Clear privacy policy: what is stored (sessions/logs/settings).
  * Provide account deletion that removes user data from Convex.
* Notification content: avoid sensitive wording on lock screen (optional setting: “discreet notifications”).

15. Technical architecture (high-level)
    Client:

* iOS app in SwiftUI
* watchOS companion app in SwiftUI
* WidgetKit for widgets
* ActivityKit for Live Activities
* App Intents for quick actions and interactive widgets/live activity actions
* Local persistence (e.g., SwiftData/CoreData) for offline logs and sync queue

Backend:

* Convex for data storage and sync
* Convex auth integration pattern with Sign in with Apple (token exchange → user record)
* Minimal server logic in MVP: CRUD + basic validation

Notifications:

* Local notifications for reminders (preferred for responsiveness)
* Remote notifications not required for MVP (unless you want cross-device scheduling)

16. MVP release criteria

* User can start/end a session reliably.
* User can log drink/water on phone and watch with <2 taps from primary surfaces.
* Reminders fire correctly (time-based and per-drink) and “Log Water” action works.
* Waterline updates correctly and recomputes after edits.
* Live Activity appears during active session and stays in sync.
* Offline logging works and syncs later without data loss.
* Basic analytics events are flowing.

17. Post-MVP roadmap (next logical increments)

* Next-day check-in + correlation insights
* Weekly goals/trends
* Social/buddy mode (accountability)
* Advanced weighting (standard drinks impact Waterline more than 1:1)
* Paid tier: insights, group mode, advanced widgets, exports

18. Open questions (high impact; answer when ready)

1) Waterline weighting: do you want +1 per alcoholic log regardless of standard drink size, or should a “double” count as +2? (Your current choice is simplicity; this affects credibility and user trust.)
Yes a double should count as +2
2) Default N and threshold: what are your preferred defaults for “water every N drinks” and “warning threshold”? (e.g., N=1, threshold=2.)
N=1 by default. This is adjustable by the user though. They can choose any number greater than 0
3) Widget interactivity requirement: are you okay requiring iOS 17+ to ensure one-tap quick logging from widgets/live activity? If not, the MVP needs a fallback deep-link flow.
Yes