# CycleSense Expansion — Design

Date: 2026-08-03
Status: Approved by Marco

## Overview

Four sub-projects, built and shippable in this order:

1. **CyclePredictor unit tests** — lock in current prediction math before touching anything else.
2. **Logging expansion** — weight, mood (State of Mind), sexual activity, cravings, basal body temperature, ovulation test results.
3. **Notifications** — local reminders for predicted period and fertile window.
4. **Home Screen widget** — cycle day and days until next period.

Decisions made during brainstorming:

- "Meals" logging means **cravings/appetite tracking** (HealthKit `appetiteChanges`), not meal timestamps or a food diary.
- Mood uses **Apple State of Mind** (`HKStateOfMind`, iOS 18+): daily-mood valence plus feeling labels, not a custom scale. The app's deployment target was raised from iOS 17.0 to 18.0 for this (decision confirmed with Marco during implementation).
- Log sheet stays a **single grouped scroll** with section headers; rarely-used sections (Body, Ovulation test) are collapsed by default.

## Sub-project 1: CyclePredictor unit tests

New `CycleSenseTests` unit-test target using Swift Testing. `CyclePredictor` is pure and
HealthKit-free, so no mocking is required.

Coverage:

- Episode grouping from flow days, including the single-missed-day bridge.
- Cycle derivation (episode start → next episode start).
- Outlier filtering: cycles outside 15–60 days and periods outside 1–10 days are ignored.
- Averaging over the last 6 cycles; 28-day default with insufficient history.
- Prediction dates: next three periods, ovulation (period start − 14 days), fertile window
  (ovulation − 5 days through ovulation + 1 day).
- Edge cases: no data, a single episode, irregular history, future-dated samples.

## Sub-project 2: Logging expansion

### Data model (`Models/Models.swift`)

The per-day log gains:

- `mood`: optional valence (`Double`, −1…1) plus a set of feeling labels.
- `weightKg`: optional `Double`. Stored metric; displayed/entered in the locale unit.
- `bbtCelsius`: optional `Double`. Same locale handling.
- `sexualActivity`: enum — none / protected / unprotected.
- `ovulationTest`: enum — negative / LH surge / estrogen surge / indeterminate.
- Cravings: new case in the existing `Symptom` enum (label "Cravings").

### HealthKit mapping (`Health/HealthKitManager.swift`)

| Item | HealthKit type | Notes |
|---|---|---|
| Weight | `HKQuantityTypeIdentifier.bodyMass` | kg internally |
| BBT | `HKQuantityTypeIdentifier.basalBodyTemperature` | °C internally |
| Sex | `HKCategoryTypeIdentifier.sexualActivity` | `HKMetadataKeySexualActivityProtectionUsed` true/false; absent for unspecified |
| Ovulation test | `HKCategoryTypeIdentifier.ovulationTestResult` | four `HKCategoryValueOvulationTestResult` values |
| Cravings | `HKCategoryTypeIdentifier.appetiteChanges` | written as `.increased` |
| Mood | `HKStateOfMind` | kind `.dailyMood`, valence, label set |

Feeling labels offered (subset of `HKStateOfMind.Label`, all available on iOS 17): calm,
content, happy, stressed, irritated, anxious, sad, discouraged.

Authorization request expands to read/write all of the above. The existing rule is unchanged:
editing or clearing a day deletes only samples this app created.

### Log sheet UI (`Views/LogView.swift`)

Single grouped scroll, one Save button, sections top to bottom:

1. Menstrual flow (existing)
2. Symptoms (existing grid + Cravings chip)
3. Mood — valence slider (very unpleasant ↔ very pleasant) + feeling label chips
4. Sexual activity — chips: none / protected / unprotected
5. Body (collapsed `DisclosureGroup`) — weight and BBT numeric fields
6. Ovulation test (collapsed) — four result options

### Surfacing

Today's-log card on the Today view shows new entries (mood, weight, BBT, sex, test result).
Insights view is deliberately untouched this round.

## Sub-project 3: Notifications

Local notifications only, via `UNUserNotificationCenter`.

- Settings gains two toggles: **period reminder** (2 days before predicted start + day-of,
  09:00 local) and **fertile-window reminder** (day the window opens, 09:00).
- Scheduling: after every prediction refresh, pending requests with stable identifiers are
  cancelled and re-added from the latest predictions.
- Permission is requested when a toggle is first enabled. If denied, the row shows a hint
  that deep-links to system Settings.

## Sub-project 4: Home Screen widget

WidgetKit extension, small and medium families.

- Small: "Day N" with the cycle progress ring and days until next period.
- Medium: adds phase name and fertile-window dates.
- Widgets cannot query HealthKit, so the main app serializes a snapshot — cycle day, phase,
  next period date, fertile window — to App Group `UserDefaults` on every data refresh and
  calls `WidgetCenter.reloadTimelines`. Requires an App Group entitlement on both targets.
- With no snapshot yet, the widget shows a neutral placeholder.

## Error handling

- HealthKit write failures surface through the existing alert pattern.
- Notification permission denial is handled in Settings (see above).
- Widget shows placeholder state rather than stale-looking data when no snapshot exists.

## Testing

- Sub-project 1 delivers the predictor suite.
- Snapshot encode/decode gets a unit test.
- Notification trigger-date computation is extracted as a pure function and unit tested.
- UI verified by running in the iOS Simulator (established workflow).
