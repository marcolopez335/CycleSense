# CycleSense Cozy Redesign — Design

Date: 2026-08-03
Status: Approved by Marco

## Goal

Make the app feel cozy and Gen-Z ("Blush Journal" direction) and replace the log sheet's
long scroll with a bento-block layout. Visual + copy only: no changes to data model,
HealthKit layer, predictions, notifications scheduling logic, or navigation structure.

Decisions made during brainstorming (visual companion mockups):

- Aesthetic: **Blush Journal** — warm cream, dusty rose, serif headers, rounded shapes.
  (Rejected: lavender-gradient "y2k" and dark "night cozy" directions.)
- Log layout: **Bento blocks** — compact tappable grid, expand-in-place.
  (Rejected: in-sheet tabs, story-style swipe cards.)
- Voice: **Soft bestie** — lowercase headers, warm short phrases, light emoji.
  (Rejected: heavy-slang "full bestie" and standard-case "warm classic".)

## 1. Theme system

New file `CycleSense/Theme.swift`:

- `Color` palette via hex initializers:
  - `Theme.background` `#FFF7F2` (cream), `Theme.card` `#FFFDFB`
  - `Theme.primary` `#C9705E` (dusty rose — buttons, selected states)
  - Block tints: pink `#F9E8E2`, sand `#F5EAE2`, lavender `#EFE7F2`, sage `#EAF0EA`,
    peach `#F9EDE4`, rose `#F9E0DA`
  - Text: `Theme.ink` `#7A4A44`, `Theme.body` `#8A5A50`, `Theme.soft` `#B98A7E`
- Type helpers: `Theme.title` (system serif design, semibold), body/labels rounded.
- Shape constants: card corner radius 22, block radius 16, soft shadow
  (`Theme.shadow`: dusty rose at ~18% opacity, radius 14, y 6).
- App forces light mode this round (`.preferredColorScheme(.light)` at root);
  cream is the identity. A dark "night cozy" variant is explicitly future work.

## 2. Log sheet → bento (`Views/LogView.swift`)

- Header: "today's check-in" (serif, lowercase) + date subline.
- 2-column `LazyVGrid` of six blocks, each showing live summary state:
  1. 🩸 flow — "medium" / "—"
  2. 🫶 symptoms — "2 logged" / "—"
  3. 🌸 mood — "calm, happy" / "—"
  4. 🧸 body — "142.5 lb · 97.9°" / "—"
  5. 💕 intimacy — "protected" / "—"
  6. 🧪 test — "LH surge" / "—"
- Tapping a block expands it full-width inline (animated); one expanded at a time;
  tapping its header again collapses. Expanded content = existing controls restyled
  (flow buttons, symptom chips, mood slider + labels, weight steppers, BBT field,
  intimacy chips, test options).
- `save 🌷` filled button pinned at bottom. Cancel stays top-left.
- Plumbing unchanged: same `@State` fields, same `DayLogEntry` build, same
  `store.logDay(date, entry:)` call, weight seeding behavior preserved.

## 3. Today (`Views/TodayView.swift`)

- Structure unchanged (ring, phase card, fertile card, today's log card).
- Serif greeting replaces plain date title, contextual:
  - menstrual: "hey, it's period day 🌷"
  - otherwise: "day N — hi you 🌿" (or "no data yet" state copy)
  - date shown as subline.
- Ring: blush gradient (rose → dusty rose), cream track.
- Cards: `Theme.card` background, tinted icons, soft shadows.
- Phase blurbs rewritten in soft-bestie voice (lowercase, warm, no medical tone shift).

## 4. Other surfaces

- **Calendar**: cream background, serif month title, marker colors moved to palette
  (period = dusty rose, predicted = pink tint, fertile = sage, ovulation ring = rose).
- **Insights**: serif lowercase section headers ("your weight", "your cycles"), chart
  recolored (points/line dusty rose, period bands pink tint), copy pass on footers.
- **Settings**: cream + card styling, copy pass ("reminders", "your data lives in
  Apple Health").
- **Onboarding**: cream, serif welcome ("welcome to cyclesense 🌷"), soft feature blurbs.
- **Widget**: cream background, lowercase "day 1" styling, dusty-rose accents.

## 5. Voice rules

- lowercase headers and labels; sentence case only where iOS conventions demand.
- Short warm phrases; max ~1 emoji per element; 🌷🧸🌸🌿 family, not 🔥💀.
- Numbers and medical facts stay plain and neutral ("3 days late", never judgment).
- Notifications: "your period's estimated in 2 days 🌷", "period expected today 🌷",
  "your fertile window opens today ✨" — `ReminderPlanner` title/body strings updated,
  planner unit tests updated to match.
- Disclaimer copy stays professional (legal tone unchanged).

## Non-goals

- No dark mode this round.
- No tab-bar or navigation changes.
- No new logged data types or metric changes.
- No animation system beyond the block expand/collapse.

## Testing

- Logic untouched → existing 22 tests stay green; only `ReminderPlannerTests` string
  expectations change with the copy.
- Visual verification in the iPhone 17 Pro simulator: onboarding, bento log flow
  (every block expand/collapse + save), Today, Calendar, Insights chart, Settings,
  widget snapshot — all screenshot-checked.
