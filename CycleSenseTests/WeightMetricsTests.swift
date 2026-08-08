import Foundation
import Testing
@testable import CycleSense

private let utc: Calendar = {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    return cal
}()

private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
    utc.date(from: DateComponents(year: y, month: m, day: d))!
}

@Suite struct WeightMetricsTests {
    private let sample: [Date: Double] = [
        day(2026, 8, 1): 64.5,
        day(2026, 7, 28): 64.9,
        day(2026, 7, 30): 64.7,
    ]

    @Test func historyIsSortedAscending() {
        let history = WeightMetrics.history(from: sample)
        #expect(history.map(\.date) == [day(2026, 7, 28), day(2026, 7, 30), day(2026, 8, 1)])
        #expect(history.map(\.kg) == [64.9, 64.7, 64.5])
    }

    @Test func lastBeforeSkipsSameDayAndLater() {
        let last = WeightMetrics.last(before: day(2026, 8, 1), in: sample)
        #expect(last?.date == day(2026, 7, 30))
        #expect(last?.kg == 64.7)
        #expect(WeightMetrics.last(before: day(2026, 7, 28), in: sample) == nil)
    }

    @Test func movingAverageUsesTrailingWindow() {
        // 7-day trailing window: Aug 1 averages Jul 28 + Jul 30 + Aug 1.
        let avg = WeightMetrics.movingAverage(WeightMetrics.history(from: sample), windowDays: 7, calendar: utc)
        #expect(avg.count == 3)
        #expect(abs(avg[2].kg - (64.9 + 64.7 + 64.5) / 3) < 0.0001)
        // First point has no earlier entries: average of itself.
        #expect(avg[0].kg == 64.9)
    }

    @Test func emptyInputGivesEmptyOutputs() {
        #expect(WeightMetrics.history(from: [:]).isEmpty)
        #expect(WeightMetrics.last(before: day(2026, 8, 1), in: [:]) == nil)
        #expect(WeightMetrics.movingAverage([], windowDays: 7, calendar: utc).isEmpty)
    }
}
