import Foundation

/// One friendly, data-backed observation shown in Insights.
struct PatternInsight: Equatable {
    /// SF Symbol name.
    let symbol: String
    let text: String
}

/// Pure correlation of logged symptoms and moods against cycle phases.
/// Only completed cycles count; the ongoing cycle is ignored so shares
/// don't shift day to day. HealthKit-free and unit-tested.
enum PatternInsights {
    /// Minimum completed cycles before any pattern is claimed.
    static let minimumCycles = 2
    /// Minimum occurrences of a symptom before it can produce an insight.
    static let minimumOccurrences = 3
    /// Share of occurrences that must land in one phase to call it a pattern.
    static let dominanceThreshold = 0.6
    /// Days before the next period that count as the "pre-period" window.
    static let prePeriodWindow = 3
    static let maximumInsights = 4

    private enum Bucket: Hashable {
        case menstrual, follicular, luteal
    }

    static func insights(
        cycles: [Cycle],
        flowByDay: [Date: FlowLevel],
        symptomsByDay: [Date: Set<Symptom>],
        moodByDay: [Date: MoodEntry],
        calendar: Calendar = .current
    ) -> [PatternInsight] {
        let completed = cycles.filter { $0.cycleLength != nil }
        guard completed.count >= minimumCycles else { return [] }

        // Map every day of every completed cycle to a phase bucket.
        var bucketByDay: [Date: Bucket] = [:]
        var prePeriodDays: Set<Date> = []
        for cycle in completed {
            guard let length = cycle.cycleLength,
                  let nextStart = calendar.date(byAdding: .day, value: length, to: cycle.start) else { continue }
            for offset in 0..<length {
                guard let dayDate = calendar.date(byAdding: .day, value: offset, to: cycle.start) else { continue }
                let daysUntilNext = length - offset
                if flowByDay[dayDate] != nil {
                    bucketByDay[dayDate] = .menstrual
                } else if daysUntilNext <= 14 {
                    bucketByDay[dayDate] = .luteal
                } else {
                    bucketByDay[dayDate] = .follicular
                }
                if daysUntilNext <= prePeriodWindow {
                    prePeriodDays.insert(dayDate)
                }
            }
            _ = nextStart
        }

        var result: [PatternInsight] = []

        // Mood dip: compare average valence, luteal vs follicular.
        let follicularMoods = moodByDay.filter { bucketByDay[$0.key] == .follicular }.map(\.value.valence)
        let lutealMoods = moodByDay.filter { bucketByDay[$0.key] == .luteal }.map(\.value.valence)
        if follicularMoods.count >= 3, lutealMoods.count >= 3 {
            let follicularMean = follicularMoods.reduce(0, +) / Double(follicularMoods.count)
            let lutealMean = lutealMoods.reduce(0, +) / Double(lutealMoods.count)
            if follicularMean - lutealMean >= 0.25 {
                result.append(PatternInsight(
                    symbol: "face.smiling.inverse",
                    text: "your mood tends to dip in the days before your period — that's really common"
                ))
            }
        }

        // Symptom concentration, most-logged symptoms first for stable order.
        let counted: [(Symptom, [Date])] = Symptom.allCases.compactMap { symptom in
            let days = symptomsByDay.filter { bucketByDay[$0.key] != nil && $0.value.contains(symptom) }.map(\.key)
            return days.count >= minimumOccurrences ? (symptom, days) : nil
        }
        .sorted { $0.1.count > $1.1.count }

        for (symptom, days) in counted {
            let name = symptom.displayName.lowercased()
            let total = days.count

            // Pre-period lead beats a generic luteal claim.
            let preCount = days.filter { prePeriodDays.contains($0) }.count
            if Double(preCount) / Double(total) >= 0.5 {
                result.append(PatternInsight(
                    symbol: symptom.systemImage,
                    text: "\(name) usually shows up in the few days before your period (\(preCount) of \(total) times)"
                ))
                continue
            }

            var perBucket: [Bucket: Int] = [:]
            for dayDate in days {
                if let bucket = bucketByDay[dayDate] {
                    perBucket[bucket, default: 0] += 1
                }
            }
            guard let (bucket, count) = perBucket.max(by: { $0.value < $1.value }),
                  Double(count) / Double(total) >= dominanceThreshold else { continue }

            let text: String
            switch bucket {
            case .menstrual:
                text = "\(name) mostly comes with your period (\(count) of \(total) times)"
            case .luteal:
                text = "you tend to log \(name) in your luteal phase (\(count) of \(total) times)"
            case .follicular:
                text = "\(name) shows up most in your follicular phase (\(count) of \(total) times)"
            }
            result.append(PatternInsight(symbol: symptom.systemImage, text: text))
        }

        return Array(result.prefix(maximumInsights))
    }
}
