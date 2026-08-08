import Foundation
import Testing
@testable import CycleSense

/// Fixed UTC calendar so results don't depend on the machine's timezone.
private let utc: Calendar = {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    return cal
}()

/// Builds a date at midnight UTC.
private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
    utc.date(from: DateComponents(year: y, month: m, day: d))!
}

/// N consecutive flow days starting at `start`.
private func flowRun(from start: Date, count: Int) -> [Date] {
    (0..<count).map { utc.date(byAdding: .day, value: $0, to: start)! }
}

@Suite struct CycleGroupingTests {
    @Test func emptyInputGivesNoCycles() {
        #expect(CyclePredictor.cycles(fromFlowDays: [], calendar: utc).isEmpty)
    }

    @Test func singleEpisodeMakesOneOpenCycle() {
        let cycles = CyclePredictor.cycles(fromFlowDays: flowRun(from: day(2026, 1, 1), count: 5), calendar: utc)
        #expect(cycles.count == 1)
        #expect(cycles[0].start == day(2026, 1, 1))
        #expect(cycles[0].periodLength == 5)
        #expect(cycles[0].cycleLength == nil)
    }

    @Test func oneMissedDayIsBridged() {
        // Days 1,2,4,5 — the gap on day 3 stays inside one episode.
        let days = [day(2026, 1, 1), day(2026, 1, 2), day(2026, 1, 4), day(2026, 1, 5)]
        let cycles = CyclePredictor.cycles(fromFlowDays: days, calendar: utc)
        #expect(cycles.count == 1)
        #expect(cycles[0].periodLength == 5)
    }

    @Test func twoDayGapSplitsEpisodes() {
        // Days 1,2 then 5,6 — two episodes; cycle length = 4 days.
        let days = [day(2026, 1, 1), day(2026, 1, 2), day(2026, 1, 5), day(2026, 1, 6)]
        let cycles = CyclePredictor.cycles(fromFlowDays: days, calendar: utc)
        #expect(cycles.count == 2)
        #expect(cycles[0].cycleLength == 4)
        #expect(cycles[1].cycleLength == nil)
    }

    @Test func duplicateAndUnsortedInputIsNormalized() {
        let days = [day(2026, 1, 2), day(2026, 1, 1), day(2026, 1, 2)]
        let cycles = CyclePredictor.cycles(fromFlowDays: days, calendar: utc)
        #expect(cycles.count == 1)
        #expect(cycles[0].start == day(2026, 1, 1))
        #expect(cycles[0].periodLength == 2)
    }
}

@Suite struct PredictionTests {
    /// Four regular 28-day cycles, 5-day periods, starting 2026-01-01.
    private var regularCycles: [Cycle] {
        var flow: [Date] = []
        for offset in [0, 28, 56, 84] {
            flow += flowRun(from: utc.date(byAdding: .day, value: offset, to: day(2026, 1, 1))!, count: 5)
        }
        return CyclePredictor.cycles(fromFlowDays: flow, calendar: utc)
    }

    @Test func noCyclesGivesNilPrediction() {
        #expect(CyclePredictor.prediction(from: [], today: day(2026, 8, 3), calendar: utc) == nil)
    }

    @Test func defaultsUsedWithSingleEpisode() {
        let cycles = CyclePredictor.cycles(fromFlowDays: flowRun(from: day(2026, 1, 1), count: 5), calendar: utc)
        let p = CyclePredictor.prediction(from: cycles, today: day(2026, 1, 10), calendar: utc)!
        #expect(p.averageCycleLength == 28)
        #expect(p.averagePeriodLength == 5)
        #expect(p.nextPeriodStart == day(2026, 1, 29))
        #expect(p.ovulationDate == day(2026, 1, 15))
        #expect(p.fertileWindow == DateInterval(start: day(2026, 1, 10), end: day(2026, 1, 16)))
    }

    @Test func regularHistoryPredictsNextPeriod() {
        // Last period start 2026-03-26 (offset 84); next = +28 = 2026-04-23.
        let p = CyclePredictor.prediction(from: regularCycles, today: day(2026, 3, 28), calendar: utc)!
        #expect(p.averageCycleLength == 28)
        #expect(p.averagePeriodLength == 5)
        #expect(p.nextPeriodStart == day(2026, 4, 23))
        #expect(p.ovulationDate == day(2026, 4, 9))
        #expect(p.fertileWindow == DateInterval(start: day(2026, 4, 4), end: day(2026, 4, 10)))
        #expect(p.upcomingPeriods.count == 3)
        #expect(p.upcomingPeriods[0] == DateInterval(start: day(2026, 4, 23), end: day(2026, 4, 27)))
        #expect(p.upcomingPeriods[1] == DateInterval(start: day(2026, 5, 21), end: day(2026, 5, 25)))
        #expect(p.upcomingPeriods[2] == DateInterval(start: day(2026, 6, 18), end: day(2026, 6, 22)))
    }

    @Test func slightlyLatePeriodIsNotRolledForward() {
        // Next = 2026-04-23; today 7 days past that — kept so UI can show "late".
        let p = CyclePredictor.prediction(from: regularCycles, today: day(2026, 4, 30), calendar: utc)!
        #expect(p.nextPeriodStart == day(2026, 4, 23))
    }

    @Test func longLapseRollsForward() {
        // Today 2026-07-01 is 69 days past 2026-04-23 (> 28): rolls to 05-21, still 41 past (> 28), rolls to 06-18 (13 past, kept).
        let p = CyclePredictor.prediction(from: regularCycles, today: day(2026, 7, 1), calendar: utc)!
        #expect(p.nextPeriodStart == day(2026, 6, 18))
    }

    @Test func implausibleCycleLengthsAreIgnored() {
        // 28, 90, 28 → only the two 28s count.
        var flow = flowRun(from: day(2026, 1, 1), count: 5)
        flow += flowRun(from: day(2026, 1, 29), count: 5)   // cycle 1: 28
        flow += flowRun(from: day(2026, 4, 29), count: 5)   // cycle 2: 90 (ignored)
        flow += flowRun(from: day(2026, 5, 27), count: 5)   // cycle 3: 28
        let cycles = CyclePredictor.cycles(fromFlowDays: flow, calendar: utc)
        let p = CyclePredictor.prediction(from: cycles, today: day(2026, 5, 30), calendar: utc)!
        #expect(p.averageCycleLength == 28)
    }

    @Test func implausiblePeriodLengthsAreIgnored() {
        // One 12-day "period" (data glitch) among 5-day periods.
        var flow = flowRun(from: day(2026, 1, 1), count: 12)
        flow += flowRun(from: day(2026, 1, 29), count: 5)
        flow += flowRun(from: day(2026, 2, 26), count: 5)
        let cycles = CyclePredictor.cycles(fromFlowDays: flow, calendar: utc)
        let p = CyclePredictor.prediction(from: cycles, today: day(2026, 3, 1), calendar: utc)!
        #expect(p.averagePeriodLength == 5)
    }

    @Test func onlyLastSixCyclesAreAveraged() {
        // Six 30-day cycles after two 20-day ones: average must be 30.
        var flow: [Date] = []
        var start = day(2025, 6, 1)
        for length in [20, 20, 30, 30, 30, 30, 30, 30] {
            flow += flowRun(from: start, count: 4)
            start = utc.date(byAdding: .day, value: length, to: start)!
        }
        flow += flowRun(from: start, count: 4)  // final open cycle
        let cycles = CyclePredictor.cycles(fromFlowDays: flow, calendar: utc)
        let p = CyclePredictor.prediction(from: cycles, today: start, calendar: utc)!
        #expect(p.averageCycleLength == 30)
    }
}
