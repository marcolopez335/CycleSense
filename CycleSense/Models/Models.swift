import Foundation

/// Flow intensity for a logged period day.
///
/// Raw values match HealthKit's menstrual flow category values
/// (`HKCategoryValueMenstrualFlow` / `HKCategoryValueVaginalBleeding`),
/// so a `FlowLevel` can be stored and read without further mapping.
/// Value 5 ("none") is intentionally absent: clearing a day deletes the
/// sample instead, and samples with value 5 are ignored when reading.
enum FlowLevel: Int, CaseIterable, Identifiable, Hashable {
    case unspecified = 1
    case light = 2
    case medium = 3
    case heavy = 4

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .unspecified: return "Unspecified"
        case .light: return "Light"
        case .medium: return "Medium"
        case .heavy: return "Heavy"
        }
    }
}

/// Symptoms the app can log. Each case maps to a HealthKit category type
/// (see `HealthKitManager`).
enum Symptom: String, CaseIterable, Identifiable, Hashable {
    case abdominalCramps
    case headache
    case bloating
    case fatigue
    case moodChanges
    case breastPain
    case lowerBackPain
    case nausea
    case acne
    case cravings

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .abdominalCramps: return "Cramps"
        case .headache: return "Headache"
        case .bloating: return "Bloating"
        case .fatigue: return "Fatigue"
        case .moodChanges: return "Mood changes"
        case .breastPain: return "Breast pain"
        case .lowerBackPain: return "Lower back pain"
        case .nausea: return "Nausea"
        case .acne: return "Acne"
        case .cravings: return "Cravings"
        }
    }

    var systemImage: String {
        switch self {
        case .abdominalCramps: return "bolt.heart"
        case .headache: return "brain.head.profile"
        case .bloating: return "wind"
        case .fatigue: return "zzz"
        case .moodChanges: return "theatermasks"
        case .breastPain: return "heart.circle"
        case .lowerBackPain: return "figure.walk"
        case .nausea: return "tornado"
        case .acne: return "face.dashed"
        case .cravings: return "fork.knife"
        }
    }

    /// Category value written to HealthKit for this symptom.
    /// Presence-style types use 0 ("unspecified/present"); appetiteChanges
    /// is value-coded, so cravings write 3 ("increased").
    var hkWriteValue: Int {
        self == .cravings ? 3 : 0
    }
}

/// One menstrual cycle derived from logged flow days.
struct Cycle: Identifiable, Hashable {
    /// First day of the period that starts this cycle (start of day).
    let start: Date
    /// Number of days with logged flow at the start of the cycle.
    let periodLength: Int
    /// Days from this cycle's start to the next cycle's start.
    /// `nil` for the most recent (still ongoing) cycle.
    let cycleLength: Int?

    var id: Date { start }
}

/// The four classic cycle phases, used for the Today screen.
enum CyclePhase: String {
    case menstrual = "Menstrual"
    case follicular = "Follicular"
    case ovulatory = "Ovulatory"
    case luteal = "Luteal"

    var blurb: String {
        switch self {
        case .menstrual: return "your period is here. energy is often at its lowest — be soft with yourself today."
        case .follicular: return "estrogen is rising. lots of people feel their energy and mood climb here."
        case .ovulatory: return "you're in your estimated fertile window, right around ovulation."
        case .luteal: return "progesterone rises after ovulation. pms feelings can show up late in this phase."
        }
    }

    var systemImage: String {
        switch self {
        case .menstrual: return "drop.fill"
        case .follicular: return "leaf.fill"
        case .ovulatory: return "sun.max.fill"
        case .luteal: return "moon.fill"
        }
    }
}

/// Forward-looking estimates computed from cycle history.
struct Prediction {
    let averageCycleLength: Int
    let averagePeriodLength: Int
    let nextPeriodStart: Date
    /// The next few predicted periods as whole-day intervals.
    let upcomingPeriods: [DateInterval]
    /// Estimated ovulation day (about 14 days before the next period).
    let ovulationDate: Date?
    /// Estimated fertile window (5 days before ovulation through 1 day after).
    let fertileWindow: DateInterval?
}

/// Feeling labels offered with a daily mood. Cases map 1:1 to
/// `HKStateOfMind.Label` values available on iOS 17 (see HealthKitManager).
enum MoodLabel: String, CaseIterable, Identifiable, Hashable {
    case calm, content, happy, stressed, irritated, anxious, sad, discouraged

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

/// One day's mood: valence on Apple's -1…1 pleasantness scale plus labels.
struct MoodEntry: Hashable {
    /// -1 (very unpleasant) … 1 (very pleasant).
    var valence: Double
    var labels: Set<MoodLabel>
}

/// Sexual activity for a day. `unspecified` covers samples from other apps
/// that carry no protection metadata.
enum SexualActivityEntry: String, CaseIterable, Identifiable, Hashable {
    case protected
    case unprotected
    case unspecified

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .protected: return "Protected"
        case .unprotected: return "Unprotected"
        case .unspecified: return "Unspecified"
        }
    }
}

/// Ovulation test result. Raw values match `HKCategoryValueOvulationTestResult`.
enum OvulationTestResult: Int, CaseIterable, Identifiable, Hashable {
    case negative = 1
    case luteinizingHormoneSurge = 2
    case indeterminate = 3
    case estrogenSurge = 4

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .negative: return "Negative"
        case .luteinizingHormoneSurge: return "LH surge"
        case .indeterminate: return "Indeterminate"
        case .estrogenSurge: return "Estrogen surge"
        }
    }
}

/// Everything the log sheet can save for one day. Nil means "not logged" —
/// saving nil clears this app's samples of that type for the day.
struct DayLogEntry {
    var flow: FlowLevel?
    var symptoms: Set<Symptom> = []
    var mood: MoodEntry?
    var weightKg: Double?
    var bbtCelsius: Double?
    var sexualActivity: SexualActivityEntry?
    var ovulationTest: OvulationTestResult?
}
