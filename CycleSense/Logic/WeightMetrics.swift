import Foundation

/// Pure helpers for turning day-keyed weight entries into history, deltas,
/// and smoothed trends. HealthKit-free so it can be unit tested.
enum WeightMetrics {
    struct Entry: Equatable {
        let date: Date
        let kg: Double
    }

    /// Entries sorted oldest first.
    static func history(from weightByDay: [Date: Double]) -> [Entry] {
        weightByDay
            .map { Entry(date: $0.key, kg: $0.value) }
            .sorted { $0.date < $1.date }
    }

    /// Most recent entry strictly before the given day, if any.
    static func last(before day: Date, in weightByDay: [Date: Double]) -> Entry? {
        history(from: weightByDay).last { $0.date < day }
    }

    /// Trailing moving average: each point averages all entries within the
    /// preceding `windowDays` (inclusive of the point itself). Tolerates
    /// sparse logging — days without entries simply don't contribute.
    static func movingAverage(_ history: [Entry], windowDays: Int, calendar: Calendar = .current) -> [Entry] {
        history.map { entry in
            let windowStart = calendar.date(byAdding: .day, value: -(windowDays - 1), to: entry.date) ?? entry.date
            let window = history.filter { $0.date >= windowStart && $0.date <= entry.date }
            let mean = window.reduce(0) { $0 + $1.kg } / Double(window.count)
            return Entry(date: entry.date, kg: mean)
        }
    }
}
