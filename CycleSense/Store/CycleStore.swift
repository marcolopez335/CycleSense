import Foundation
import SwiftUI
import WidgetKit

/// Observable source of truth for the UI. Mirrors HealthKit data into
/// day-keyed dictionaries and derives cycles and predictions from them.
@MainActor
final class CycleStore: ObservableObject {
    /// Logged flow keyed by start-of-day.
    @Published private(set) var flowByDay: [Date: FlowLevel] = [:]
    /// Logged symptoms keyed by start-of-day.
    @Published private(set) var symptomsByDay: [Date: Set<Symptom>] = [:]
    /// Expanded log data keyed by start-of-day.
    @Published private(set) var moodByDay: [Date: MoodEntry] = [:]
    @Published private(set) var weightByDay: [Date: Double] = [:]
    @Published private(set) var bbtByDay: [Date: Double] = [:]
    @Published private(set) var sexByDay: [Date: SexualActivityEntry] = [:]
    @Published private(set) var ovulationTestByDay: [Date: OvulationTestResult] = [:]
    /// Cycles derived from `flowByDay`, oldest first.
    @Published private(set) var cycles: [Cycle] = []
    @Published private(set) var prediction: Prediction?
    @Published private(set) var isRefreshing = false
    @Published var lastError: String?

    let healthAvailable = HealthKitManager.isHealthDataAvailable

    private let calendar = Calendar.current
    private let manager = HealthKitManager.shared

    /// How a calendar day should be marked.
    enum DayMark {
        case period(FlowLevel)
        case predictedPeriod
        case fertile
        case ovulation
    }

    // MARK: - HealthKit lifecycle

    func requestAccessAndRefresh() async {
        guard healthAvailable else { return }
        do {
            try await manager.requestAuthorization()
            await refresh()
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Reloads the last two years of data from HealthKit.
    func refresh() async {
        guard healthAvailable else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            async let flow = manager.fetchFlowByDay(monthsBack: 24)
            async let symptoms = manager.fetchSymptomsByDay(monthsBack: 24)
            async let mood = manager.fetchMoodByDay(monthsBack: 24)
            async let weight = manager.fetchWeightByDay(monthsBack: 24)
            async let bbt = manager.fetchBBTByDay(monthsBack: 24)
            async let sex = manager.fetchSexualActivityByDay(monthsBack: 24)
            async let ovulation = manager.fetchOvulationTestsByDay(monthsBack: 24)
            flowByDay = try await flow
            symptomsByDay = try await symptoms
            moodByDay = try await mood
            weightByDay = try await weight
            bbtByDay = try await bbt
            sexByDay = try await sex
            ovulationTestByDay = try await ovulation
            recompute()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Logging

    /// Saves one day's full log entry to HealthKit and updates local state.
    /// Nil fields clear this app's samples of that type for the day.
    func logDay(_ day: Date, entry: DayLogEntry) async {
        let dayStart = calendar.startOfDay(for: day)
        do {
            if let flow = entry.flow {
                // First day of a period if the previous day has no flow logged.
                // Backfilling an earlier day can leave the next day's metadata
                // stale; the grouping in CyclePredictor does not rely on it.
                let previousDay = calendar.date(byAdding: .day, value: -1, to: dayStart)
                let isCycleStart = previousDay.map { flowByDay[$0] == nil } ?? true
                try await manager.saveFlow(flow, on: dayStart, cycleStart: isCycleStart)
                flowByDay[dayStart] = flow
            } else {
                try await manager.deleteFlow(on: dayStart)
                // If the flow came from another app, it will reappear on the
                // next refresh — HealthKit only lets us delete our own samples.
                flowByDay.removeValue(forKey: dayStart)
            }
            try await manager.saveMood(entry.mood, on: dayStart)
            try await manager.saveWeight(entry.weightKg, on: dayStart)
            try await manager.saveBBT(entry.bbtCelsius, on: dayStart)
            try await manager.saveSexualActivity(entry.sexualActivity, on: dayStart)
            try await manager.saveOvulationTest(entry.ovulationTest, on: dayStart)
        } catch {
            lastError = error.localizedDescription
        }
        await manager.saveSymptoms(entry.symptoms, on: dayStart)

        setOrRemove(entry.symptoms.isEmpty ? nil : entry.symptoms, in: &symptomsByDay, at: dayStart)
        setOrRemove(entry.mood, in: &moodByDay, at: dayStart)
        setOrRemove(entry.weightKg, in: &weightByDay, at: dayStart)
        setOrRemove(entry.bbtCelsius, in: &bbtByDay, at: dayStart)
        setOrRemove(entry.sexualActivity, in: &sexByDay, at: dayStart)
        setOrRemove(entry.ovulationTest, in: &ovulationTestByDay, at: dayStart)
        recompute()
    }

    private func setOrRemove<V>(_ value: V?, in dict: inout [Date: V], at key: Date) {
        if let value {
            dict[key] = value
        } else {
            dict.removeValue(forKey: key)
        }
    }

    private func recompute() {
        cycles = CyclePredictor.cycles(fromFlowDays: Array(flowByDay.keys), calendar: calendar)
        prediction = CyclePredictor.prediction(from: cycles, today: Date(), calendar: calendar)
        let currentPrediction = prediction
        Task { await NotificationScheduler.reschedule(prediction: currentPrediction) }
        publishWidgetSnapshot()
    }

    private func publishWidgetSnapshot() {
        let snapshot = WidgetSnapshot(
            cycleDay: currentCycleDay,
            phase: currentPhase?.rawValue,
            nextPeriodStart: prediction?.nextPeriodStart,
            fertileStart: prediction?.fertileWindow?.start,
            fertileEnd: prediction?.fertileWindow?.end,
            generatedAt: Date()
        )
        snapshot.write(to: WidgetSnapshot.appGroupDefaults)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Derived state

    var lastPeriodStart: Date? {
        cycles.last?.start
    }

    /// 1-based day within the current cycle, or `nil` before any data exists.
    var currentCycleDay: Int? {
        guard let start = lastPeriodStart else { return nil }
        let days = calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: Date())).day ?? 0
        return days >= 0 ? days + 1 : nil
    }

    /// Days until the predicted next period. Negative means the period is late.
    var daysUntilNextPeriod: Int? {
        guard let next = prediction?.nextPeriodStart else { return nil }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: next).day
    }

    var currentPhase: CyclePhase? {
        guard lastPeriodStart != nil else { return nil }
        let today = calendar.startOfDay(for: Date())
        if flowByDay[today] != nil { return .menstrual }
        guard let prediction, let ovulation = prediction.ovulationDate else { return .follicular }
        if let window = prediction.fertileWindow, window.contains(today) { return .ovulatory }
        return today < ovulation ? .follicular : .luteal
    }

    /// Marker for a calendar day: real flow first, then predictions.
    func mark(for date: Date) -> DayMark? {
        let day = calendar.startOfDay(for: date)
        if let flow = flowByDay[day] { return .period(flow) }
        guard let prediction else { return nil }
        if let ovulation = prediction.ovulationDate, calendar.isDate(day, inSameDayAs: ovulation) {
            return .ovulation
        }
        if let window = prediction.fertileWindow, window.contains(day) {
            return .fertile
        }
        for interval in prediction.upcomingPeriods where interval.contains(day) {
            return .predictedPeriod
        }
        return nil
    }

    func symptoms(on date: Date) -> Set<Symptom> {
        symptomsByDay[calendar.startOfDay(for: date)] ?? []
    }

    func flow(on date: Date) -> FlowLevel? {
        flowByDay[calendar.startOfDay(for: date)]
    }

    func dayLogEntry(on date: Date) -> DayLogEntry {
        let day = calendar.startOfDay(for: date)
        return DayLogEntry(
            flow: flowByDay[day],
            symptoms: symptomsByDay[day] ?? [],
            mood: moodByDay[day],
            weightKg: weightByDay[day],
            bbtCelsius: bbtByDay[day],
            sexualActivity: sexByDay[day],
            ovulationTest: ovulationTestByDay[day]
        )
    }
}
