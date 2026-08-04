# CycleSense

A menstrual cycle tracking app for iOS, built with SwiftUI and fully integrated
with Apple Health (HealthKit). Everything the user logs is stored in their
private Health record — the app has no backend and no account system.

## Features

- **Today dashboard** — current cycle day on a progress ring, days until the
  next period (or how many days late), current cycle phase, and today's log
  at a glance.
- **Calendar** — month view with markers for logged period days, predicted
  periods, the estimated fertile window, and estimated ovulation. Tap any day
  to log or edit it.
- **Logging** — flow level (unspecified / light / medium / heavy) plus ten
  symptoms (cramps, headache, bloating, fatigue, mood changes, breast pain,
  lower back pain, nausea, acne, cravings), daily mood (State of Mind),
  sexual activity, weight, basal body temperature, and ovulation test
  results — all saved straight to Apple Health.
- **Insights** — average cycle and period length, upcoming estimates, and a
  full cycle history derived from Health data.
- **Predictions** — next three periods, fertile window, and ovulation
  estimated from the last 6 cycles (28-day default until enough history
  exists).
- **Reminders** — optional local notifications 2 days before and on the
  estimated period start (9:00), plus one when the fertile window opens.
- **Home Screen widget** — small and medium widgets with the current cycle
  day, days to the next period, phase, and fertile window.

## Apple Health integration

| What | How |
| --- | --- |
| Period days | `HKCategoryTypeIdentifier.menstrualFlow` category samples, read and written. Raw values match `HKCategoryValueMenstrualFlow` / `HKCategoryValueVaginalBleeding` (1–4); the required `HKMetadataKeyMenstrualCycleStart` metadata is set based on whether the previous day has flow. |
| Symptoms | One category sample per selected symptom per day (`abdominalCramps`, `headache`, `bloating`, `fatigue`, `moodChanges`, `breastPain`, `lowerBackPain`, `nausea`, `acne`), value `0` (unspecified severity / present). Cravings write `appetiteChanges` with value `3` (increased). |
| Mood | `HKStateOfMind` daily-mood samples (iOS 18+): valence on the −1…1 scale plus feeling labels. Shows up under Mental Wellbeing in the Health app. |
| Weight / BBT | `bodyMass` (kg) and `basalBodyTemperature` (°C) quantity samples; entered and displayed in the locale's units. |
| Sexual activity | `sexualActivity` category samples with `HKMetadataKeySexualActivityProtectionUsed` metadata (protected / unprotected / unspecified). |
| Ovulation tests | `ovulationTestResult` category samples (negative / LH surge / estrogen surge / indeterminate). |
| Reads | Last 24 months of all of the above, from **all** sources — data logged in the Health app or other cycle apps shows up here too. |
| Deletes | Editing or clearing a day deletes only samples this app created; HealthKit forbids deleting other apps' data. |

The HealthKit capability is configured in `CycleSense/CycleSense.entitlements`,
and the two required usage strings (`NSHealthShareUsageDescription`,
`NSHealthUpdateUsageDescription`) are injected via build settings — no manual
Info.plist editing needed.

## Getting started

Requirements: **Xcode 16 or newer** (the project uses folder-synchronized
groups), iOS 18+ deployment target (State of Mind requires iOS 18).

1. Open `CycleSense.xcodeproj` in Xcode.
2. In the target's *Signing & Capabilities* tab, select your development team
   and change the bundle identifier (`com.example.CycleSense`) to your own.
3. Run on a simulator or device. The simulator's Health app works for testing;
   a physical device is best for real data.
4. On first launch, tap **Connect Apple Health** and grant access. Permissions
   can be changed later in Health → Sharing → Apps → CycleSense.

## Project structure

```
CycleSense/
├── CycleSense.xcodeproj
├── CycleSense/
│   ├── CycleSenseApp.swift        App entry point
│   ├── CycleSense.entitlements    HealthKit + App Group capabilities
│   ├── Models/Models.swift        FlowLevel, Symptom, Cycle, CyclePhase, Prediction, DayLogEntry, …
│   ├── Health/HealthKitManager.swift  Async HealthKit read/write wrapper
│   ├── Health/NotificationScheduler.swift  Local reminder scheduling
│   ├── Store/CycleStore.swift     Observable app state + day classification
│   ├── Logic/CyclePredictor.swift Pure cycle-derivation and prediction math
│   ├── Logic/ReminderPlanner.swift    Pure reminder planning
│   └── Views/                     ContentView, Onboarding, Today, Calendar, Log, Insights, Settings
├── CycleSenseShared/WidgetSnapshot.swift  App ↔ widget data (App Group)
├── CycleSenseWidget/              WidgetKit extension (small + medium)
└── CycleSenseTests/               Predictor, planner, and snapshot unit tests
```

`CyclePredictor` and `ReminderPlanner` are deterministic and HealthKit-free;
`CycleSenseTests` covers both plus the widget snapshot codec. Run the suite
with `xcodebuild test -scheme CycleSense` or ⌘U in Xcode.

## How predictions work

1. Logged flow days are grouped into period *episodes* (a single missed day
   inside a period is bridged).
2. A cycle runs from the start of one episode to the start of the next.
3. Averages use the last 6 cycles, ignoring implausible lengths (cycles
   outside 15–60 days, periods outside 1–10 days).
4. Next period = last period start + average cycle length; ovulation is
   estimated 14 days before it, with a fertile window from 5 days before
   ovulation through the day after.

## Disclaimer

CycleSense is not a medical device. Predictions are statistical estimates for
informational purposes only and must not be used as contraception or medical
advice.

## Ideas for next steps

- watchOS companion app
- Insights charts (cycle length trend, BBT curve, mood vs. cycle phase)
- Log editing from the Calendar for weight/BBT/mood history
