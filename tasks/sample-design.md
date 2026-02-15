### High-level aesthetic

A **Swiss-modernist, instrument-panel UI**: rigid grid, typography-first hierarchy, monochrome palette, and “system console” semantics. It reads like a **calm control surface** rather than a consumer lifestyle app—more “operational dashboard / measurement device” than “wellness tracker.”

Key vibes to preserve:

* **International/Swiss layout discipline** (hard grid, modular blocks, consistent gutters)
* **Neo-brutalist restraint** (hard rules, boxed regions, minimal decoration, high contrast)
* **Editorial hierarchy** (large headlines + tiny metadata labels)
* **Systems UI language** (status flags, protocol names, “//” separators, versioning)

---

## Color + materials (very limited palette)

**Paper-like warm neutral base** with stark ink lines.

* **Primary background:** warm off-white / bone (approx `#F0EEEA`)
* **Section header bands / panels:** slightly darker warm gray (approx `#E8E7E3` to `#DCD8D2`)
* **Primary ink:** near-black (approx `#111111`)
* **Secondary ink:** mid-gray for helper text (approx `#6F6C68`)
* **Tertiary / placeholder:** very light gray for inactive numerals (approx `#CFCBC6`)
* **Accent:** almost none; state is communicated via **ink weight + inversion** (black bar) and occasional **warning red** (when used, keep it sparse and flat, no gradients)

No shadows, no glassmorphism, no blur. Everything is flat and printed.

---

## Typography system (editorial + utilitarian)

Two-tier type behavior: **big declarative headlines** + **small technical labels**.

**1) Display / headline**

* Heavy grotesk / neo-grotesk (think Helvetica Now / Neue Haas Grotesk / Inter Tight / SF Pro Display but heavier)
* Very large sizes, tight leading, often stacked across multiple lines
* Used as a *graphic element* (“WAITING FOR FIRST INPUT”, “SETTINGS”, “WEEKLY PERFORMANCE”)

**2) Technical labels**

* Small uppercase labels with slight tracking
* Uses structured syntax: `PACER // REPORTS`, `SESSION LOG // STATUS EMPTY`, `WEEK_04_SUMMARY`
* Feels like a console header or spec sheet

**3) Numerals**

* Big numeric counters with **very low contrast** when inactive (ghosted “00”)
* Active numerals should be bold + high contrast, aligned to grid edges

**Typography rules**

* Prefer uppercase for system labels and buttons
* Prefer short, declarative phrases
* Use **slash separators** and **protocol naming** (e.g., `PROTOCOL 01`, `SYSTEM_IDLE`, `SYS_01`)
* Avoid playful copy, emoji, or motivational language

---

## Layout + grid (the most important part)

The UI is built from **rectangular regions** separated by **hairline-to-1px rules** (often near-black). It’s basically a **modular poster grid**.

* Strong vertical rhythm: consistent spacing between sections
* Consistent gutters (feels like 12–16pt on iPhone)
* Frequent **2-column splits** for symmetric modules (e.g., Alcohol vs Water)
* Sections are delineated by **full-width divider lines**
* Cards are not “cards” with shadows; they are **cells** in a grid

**Corner radius**

* Outer device/screen has radius.
* Internal components are **square** (0 radius). Any rounding should be minimal and rare.

---

## Components (patterns to reproduce)

### 1) Header bars

* Thin top band with left/right aligned metadata:

  * Left: `WATERLINE // V1.0`
  * Right: `SYSTEM_IDLE` / `CONFIG // SYS_01`
* Minimal iconography (close “X”, back arrow)
* Often separated from content by a rule line

### 2) Section headers

* Full-width strip with small uppercase title (e.g., “WATER & NON-ALCOHOLIC”)
* Background slightly darker than base
* Bottom border line

### 3) Grid cells / selection tiles

* Two-column grid of tiles
* Each tile contains:

  * small metadata (e.g., `250ML`) top-left
  * large bold item name (stacked) center-left
  * small outlined tag (e.g., `0.0% ABV`) near bottom-left
* Tiles separated by rules; no spacing gaps—just borders

### 4) Primary actions as “system controls”

* Large action blocks with a small plus sign and big label:

  * `+` then `LOG DRINK`
* Subtext is tiny and technical (“START SESSION”, “PRE-HYDRATE”)

### 5) Status / console callouts

* Big bold status message block (“WAITING FOR FIRST INPUT”)
* Followed by protocol row:

  * left label: `PROTOCOL 01`
  * right label: `1:1 RATIO RECOMMENDED`
* Followed by small paragraph copy in uppercase/compact sentence case (still feels technical)

### 6) Inverted bottom command bar

* Persistent bottom bar in black with white text
* Acts like a “system footer”
* Example: `SYSTEM READY` or `SAVE CONFIGURATION`
* If there’s a secondary affordance, it’s tiny (e.g., small glyph cluster)

### 7) Controls (settings)

* Toggles are stark, geometric, high-contrast (no iOS default styling)
* Slider is a thin rule line with a **square thumb**
* Chips are rectangular pills:

  * Active: black fill, white text
  * Inactive: outlined or light fill
* “EDIT” buttons are small outlined rectangles aligned to right edge

### 8) Reporting screen (dashboard minimalism)

* Big page title
* Metrics shown as boxed modules:

  * “TOTAL UNITS” with huge number
  * “HYDRATION SCORE” with huge percentage
* Charts are minimal (thin lines, tiny labels), almost like schematic marks
* “Health insight” is a bold statement inside a bordered block, with a single bar indicator underneath

---

## Iconography + visual language

* Very sparse icons: back arrow, close X, maybe tiny glyph clusters
* No illustrative icons, no emojis, no skeuomorphic symbols
* Communication is through:

  * **rules**
  * **type weight**
  * **inversion**
  * **alignment**
  * **numeric scale**

---

## Motion / interaction feel (calm-tech)

* Transitions should be **subtle and linear**:

  * quick fade/slide, no bounce
* Waterline animation should feel **damped** (instrument behavior):

  * the line moves with slight inertia, not jumpy
* Warnings should not flash; they should **change state weight**:

  * introduce a red band/label, or invert a block, but keep it controlled

---

## Content voice (system + protocol tone)

Use language that sounds like a measured device:

* `SYSTEM_READY`, `SYSTEM_IDLE`
* `PROTOCOL 01`, `RATIO RECOMMENDED`
* `STATUS EMPTY`, `CONFIG // SYS_01`
* Short declarative insights: `WEEKEND VELOCITY EXCEEDS OPTIMAL THRESHOLD BY 14%`

Avoid:

* “You got this!”, streaks, gamified celebrations
* Overpromising (“prevents hangovers”)
* Medical framing (BAC, dehydration meter)

---

# Copy-pastable style prompt for an AI design agent

Design a mobile UI in a Swiss-modernist instrument-panel style: monochrome warm off-white base (#F0EEEA), near-black rules (#111111), no shadows or gradients. Build the layout from strict rectangular modules and 1px divider lines, often in 2-column grids. Typography-first hierarchy: huge bold grotesk headlines for state and section titles, tiny uppercase technical labels with slight tracking for metadata (use “//” separators, versioning, status flags like SYSTEM_IDLE, PROTOCOL 01). Components are square-cornered cells with borders, not cards. Primary actions appear as large control blocks with a plus sign and bold label (LOG DRINK / LOG WATER). Use an inverted black bottom command bar with white text for primary commands (SYSTEM READY / SAVE CONFIGURATION). Controls are stark: square-thumb sliders, geometric toggles, rectangular chips (black fill for active). Charts are schematic minimal lines with tiny labels. Motion is calm and damped, like instrumentation, not playful.

If you want, I can also translate this into a compact “design tokens + component spec” (spacing scale, type scale, stroke weights, corner radii, state colors) tailored to SwiftUI.
