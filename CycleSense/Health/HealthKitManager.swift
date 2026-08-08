import Foundation
import HealthKit

/// Thin async wrapper around `HKHealthStore` for the cycle data this app
/// reads and writes. All dates are normalized to start-of-day; cycle
/// tracking samples are stored as point-in-time samples at midnight, the
/// same convention the Health app uses.
final class HealthKitManager {
    static let shared = HealthKitManager()

    private let healthStore = HKHealthStore()

    private init() {}

    static var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    private var flowType: HKCategoryType {
        HKCategoryType(.menstrualFlow)
    }

    private static let symptomIdentifiers: [Symptom: HKCategoryTypeIdentifier] = [
        .abdominalCramps: .abdominalCramps,
        .headache: .headache,
        .bloating: .bloating,
        .fatigue: .fatigue,
        .moodChanges: .moodChanges,
        .breastPain: .breastPain,
        .lowerBackPain: .lowerBackPain,
        .nausea: .nausea,
        .acne: .acne,
        .cravings: .appetiteChanges,
    ]

    private func type(for symptom: Symptom) -> HKCategoryType {
        guard let identifier = Self.symptomIdentifiers[symptom] else {
            fatalError("Missing HealthKit identifier for symptom \(symptom.rawValue)")
        }
        return HKCategoryType(identifier)
    }

    private var weightType: HKQuantityType { HKQuantityType(.bodyMass) }
    private var bbtType: HKQuantityType { HKQuantityType(.basalBodyTemperature) }
    private var sexType: HKCategoryType { HKCategoryType(.sexualActivity) }
    private var ovulationTestType: HKCategoryType { HKCategoryType(.ovulationTestResult) }
    private var moodType: HKSampleType { HKObjectType.stateOfMindType() }

    private static let moodLabelMap: [MoodLabel: HKStateOfMind.Label] = [
        .calm: .calm, .content: .content, .happy: .happy, .stressed: .stressed,
        .irritated: .irritated, .anxious: .anxious, .sad: .sad, .discouraged: .discouraged,
    ]

    // MARK: - Authorization

    /// Asks for read and write access to menstrual flow and all symptom types.
    /// HealthKit shows its permission sheet only the first time; afterwards
    /// the user manages access in the Health app.
    func requestAuthorization() async throws {
        var shareTypes: Set<HKSampleType> = [flowType, weightType, bbtType, sexType, ovulationTestType, moodType]
        var readTypes: Set<HKObjectType> = [flowType, weightType, bbtType, sexType, ovulationTestType, moodType]
        for symptom in Symptom.allCases {
            let categoryType = type(for: symptom)
            shareTypes.insert(categoryType)
            readTypes.insert(categoryType)
        }
        try await healthStore.requestAuthorization(toShare: shareTypes, read: readTypes)
    }

    var isFlowWriteAuthorized: Bool {
        healthStore.authorizationStatus(for: flowType) == .sharingAuthorized
    }

    // MARK: - Reading

    /// Menstrual flow samples bucketed by calendar day. Samples with the
    /// "none" value (5) are skipped; if several sources logged the same day,
    /// the heavier reading wins.
    func fetchFlowByDay(monthsBack: Int = 24) async throws -> [Date: FlowLevel] {
        let calendar = Calendar.current
        let (start, end) = queryRange(monthsBack: monthsBack, calendar: calendar)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: flowType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let samples = try await descriptor.result(for: healthStore)

        var byDay: [Date: FlowLevel] = [:]
        for sample in samples {
            guard let level = FlowLevel(rawValue: sample.value) else { continue }
            let day = calendar.startOfDay(for: sample.startDate)
            if let existing = byDay[day], existing.rawValue >= level.rawValue { continue }
            byDay[day] = level
        }
        return byDay
    }

    /// Symptoms bucketed by calendar day, across all tracked symptom types.
    func fetchSymptomsByDay(monthsBack: Int = 24) async throws -> [Date: Set<Symptom>] {
        let calendar = Calendar.current
        let (start, end) = queryRange(monthsBack: monthsBack, calendar: calendar)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])

        var byDay: [Date: Set<Symptom>] = [:]
        for symptom in Symptom.allCases {
            let descriptor = HKSampleQueryDescriptor(
                predicates: [.categorySample(type: type(for: symptom), predicate: predicate)],
                sortDescriptors: []
            )
            let samples = try await descriptor.result(for: healthStore)
            for sample in samples {
                // Both the severity and presence value sets use 1 for "not present".
                guard sample.value != 1 else { continue }
                let day = calendar.startOfDay(for: sample.startDate)
                byDay[day, default: []].insert(symptom)
            }
        }
        return byDay
    }

    /// Latest body-mass reading per day, in kilograms.
    func fetchWeightByDay(monthsBack: Int = 24) async throws -> [Date: Double] {
        try await fetchQuantityByDay(type: weightType, unit: .gramUnit(with: .kilo), monthsBack: monthsBack)
    }

    /// Latest basal body temperature per day, in °C.
    func fetchBBTByDay(monthsBack: Int = 24) async throws -> [Date: Double] {
        try await fetchQuantityByDay(type: bbtType, unit: .degreeCelsius(), monthsBack: monthsBack)
    }

    private func fetchQuantityByDay(type: HKQuantityType, unit: HKUnit, monthsBack: Int) async throws -> [Date: Double] {
        let calendar = Calendar.current
        let (start, end) = queryRange(monthsBack: monthsBack, calendar: calendar)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let samples = try await descriptor.result(for: healthStore)
        var byDay: [Date: Double] = [:]
        for sample in samples {
            // Sorted ascending, so the latest sample of the day wins.
            byDay[calendar.startOfDay(for: sample.startDate)] = sample.quantity.doubleValue(for: unit)
        }
        return byDay
    }

    /// Sexual activity per day. Protection metadata maps to the entry case.
    func fetchSexualActivityByDay(monthsBack: Int = 24) async throws -> [Date: SexualActivityEntry] {
        let calendar = Calendar.current
        let (start, end) = queryRange(monthsBack: monthsBack, calendar: calendar)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: sexType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let samples = try await descriptor.result(for: healthStore)
        var byDay: [Date: SexualActivityEntry] = [:]
        for sample in samples {
            let entry: SexualActivityEntry
            if let used = sample.metadata?[HKMetadataKeySexualActivityProtectionUsed] as? Bool {
                entry = used ? .protected : .unprotected
            } else {
                entry = .unspecified
            }
            byDay[calendar.startOfDay(for: sample.startDate)] = entry
        }
        return byDay
    }

    /// Ovulation test results per day.
    func fetchOvulationTestsByDay(monthsBack: Int = 24) async throws -> [Date: OvulationTestResult] {
        let calendar = Calendar.current
        let (start, end) = queryRange(monthsBack: monthsBack, calendar: calendar)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: ovulationTestType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let samples = try await descriptor.result(for: healthStore)
        var byDay: [Date: OvulationTestResult] = [:]
        for sample in samples {
            guard let result = OvulationTestResult(rawValue: sample.value) else { continue }
            byDay[calendar.startOfDay(for: sample.startDate)] = result
        }
        return byDay
    }

    /// Daily-mood State of Mind entries per day.
    func fetchMoodByDay(monthsBack: Int = 24) async throws -> [Date: MoodEntry] {
        let calendar = Calendar.current
        let (start, end) = queryRange(monthsBack: monthsBack, calendar: calendar)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.stateOfMind(predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let samples = try await descriptor.result(for: healthStore)
        var byDay: [Date: MoodEntry] = [:]
        let reverseLabelMap = Dictionary(uniqueKeysWithValues: Self.moodLabelMap.map { ($1, $0) })
        for sample in samples where sample.kind == .dailyMood {
            let labels = Set(sample.labels.compactMap { reverseLabelMap[$0] })
            byDay[calendar.startOfDay(for: sample.startDate)] = MoodEntry(valence: sample.valence, labels: labels)
        }
        return byDay
    }

    private func queryRange(monthsBack: Int, calendar: Calendar) -> (Date, Date) {
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? Date()
        let start = calendar.date(byAdding: .month, value: -monthsBack, to: end) ?? end
        return (start, end)
    }

    // MARK: - Writing

    /// Replaces this app's flow sample for the given day.
    ///
    /// HealthKit requires the `HKMetadataKeyMenstrualCycleStart` metadata on
    /// every menstrual flow sample; `cycleStart` should be true when the
    /// previous day has no logged flow.
    func saveFlow(_ level: FlowLevel, on day: Date, cycleStart: Bool) async throws {
        let dayStart = Calendar.current.startOfDay(for: day)
        try await deleteOwnSamples(of: flowType, on: dayStart)
        let metadata: [String: Any] = [HKMetadataKeyMenstrualCycleStart: cycleStart]
        let sample = HKCategorySample(
            type: flowType,
            value: level.rawValue,
            start: dayStart,
            end: dayStart,
            metadata: metadata
        )
        try await healthStore.save(sample)
    }

    /// Deletes this app's flow sample for the given day. Samples written by
    /// other apps can only be deleted from the Health app itself.
    func deleteFlow(on day: Date) async throws {
        try await deleteOwnSamples(of: flowType, on: Calendar.current.startOfDay(for: day))
    }

    /// Replaces this app's symptom samples for the given day with the given
    /// set. Best-effort: a type the user declined to share is skipped rather
    /// than failing the whole save.
    func saveSymptoms(_ symptoms: Set<Symptom>, on day: Date) async {
        let dayStart = Calendar.current.startOfDay(for: day)
        for symptom in Symptom.allCases {
            let categoryType = type(for: symptom)
            try? await deleteOwnSamples(of: categoryType, on: dayStart)
            if symptoms.contains(symptom) {
                let sample = HKCategorySample(type: categoryType, value: symptom.hkWriteValue, start: dayStart, end: dayStart)
                try? await healthStore.save(sample)
            }
        }
    }

    // MARK: - Writing (expanded log)

    /// Replaces this app's body-mass sample for the day.
    func saveWeight(_ kilograms: Double?, on day: Date) async throws {
        let dayStart = Calendar.current.startOfDay(for: day)
        try await deleteOwnSamples(of: weightType, on: dayStart)
        guard let kilograms else { return }
        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kilograms)
        let sample = HKQuantitySample(type: weightType, quantity: quantity, start: dayStart, end: dayStart)
        try await healthStore.save(sample)
    }

    /// Replaces this app's basal body temperature sample for the day.
    func saveBBT(_ celsius: Double?, on day: Date) async throws {
        let dayStart = Calendar.current.startOfDay(for: day)
        try await deleteOwnSamples(of: bbtType, on: dayStart)
        guard let celsius else { return }
        let quantity = HKQuantity(unit: .degreeCelsius(), doubleValue: celsius)
        let sample = HKQuantitySample(type: bbtType, quantity: quantity, start: dayStart, end: dayStart)
        try await healthStore.save(sample)
    }

    /// Replaces this app's sexual-activity sample for the day.
    func saveSexualActivity(_ entry: SexualActivityEntry?, on day: Date) async throws {
        let dayStart = Calendar.current.startOfDay(for: day)
        try await deleteOwnSamples(of: sexType, on: dayStart)
        guard let entry else { return }
        var metadata: [String: Any] = [:]
        switch entry {
        case .protected: metadata[HKMetadataKeySexualActivityProtectionUsed] = true
        case .unprotected: metadata[HKMetadataKeySexualActivityProtectionUsed] = false
        case .unspecified: break
        }
        let sample = HKCategorySample(
            type: sexType,
            value: HKCategoryValue.notApplicable.rawValue,
            start: dayStart,
            end: dayStart,
            metadata: metadata.isEmpty ? nil : metadata
        )
        try await healthStore.save(sample)
    }

    /// Replaces this app's ovulation test result for the day.
    func saveOvulationTest(_ result: OvulationTestResult?, on day: Date) async throws {
        let dayStart = Calendar.current.startOfDay(for: day)
        try await deleteOwnSamples(of: ovulationTestType, on: dayStart)
        guard let result else { return }
        let sample = HKCategorySample(type: ovulationTestType, value: result.rawValue, start: dayStart, end: dayStart)
        try await healthStore.save(sample)
    }

    /// Replaces this app's daily-mood State of Mind sample for the day.
    func saveMood(_ mood: MoodEntry?, on day: Date) async throws {
        let dayStart = Calendar.current.startOfDay(for: day)
        try await deleteOwnSamples(of: moodType, on: dayStart)
        guard let mood else { return }
        let labels = mood.labels.compactMap { Self.moodLabelMap[$0] }
        let sample = HKStateOfMind(
            date: dayStart,
            kind: .dailyMood,
            valence: mood.valence,
            labels: labels,
            associations: []
        )
        try await healthStore.save(sample)
    }

    /// Deletes samples of the given type that this app created on that day.
    private func deleteOwnSamples(of sampleType: HKSampleType, on dayStart: Date) async throws {
        guard let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) else { return }
        let predicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: [])
        _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int, Error>) in
            healthStore.deleteObjects(of: sampleType, predicate: predicate) { _, deletedCount, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: deletedCount)
                }
            }
        }
    }
}
