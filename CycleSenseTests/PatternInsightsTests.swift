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

private func addDays(_ base: Date, _ offset: Int) -> Date {
    utc.date(byAdding: .day, value: offset, to: base)!
}

/// Three completed 28-day cycles + one ongoing, starting 2026-01-01.
/// Flow on the first 5 days of each.
private struct Fixture {
    var flowByDay: [Date: FlowLevel] = [:]
    var symptomsByDay: [Date: Set<Symptom>] = [:]
    var moodByDay: [Date: MoodEntry] = [:]
    let starts = [day(2026, 1, 1), day(2026, 1, 29), day(2026, 2, 26), day(2026, 3, 26)]

    init() {
        for start in starts {
            for offset in 0..<5 {
                flowByDay[addDays(start, offset)] = .medium
            }
        }
    }

    var cycles: [Cycle] {
        CyclePredictor.cycles(fromFlowDays: Array(flowByDay.keys), calendar: utc)
    }

    func insights() -> [PatternInsight] {
        PatternInsights.insights(
            cycles: cycles,
            flowByDay: flowByDay,
            symptomsByDay: symptomsByDay,
            moodByDay: moodByDay,
            calendar: utc
        )
    }
}

@Suite struct PatternInsightsTests {
    @Test func tooLittleHistoryGivesNoInsights() {
        var f = Fixture()
        f.flowByDay = [day(2026, 1, 1): .medium]  // single episode → no completed cycles
        let result = PatternInsights.insights(
            cycles: CyclePredictor.cycles(fromFlowDays: Array(f.flowByDay.keys), calendar: utc),
            flowByDay: f.flowByDay,
            symptomsByDay: [:],
            moodByDay: [:],
            calendar: utc
        )
        #expect(result.isEmpty)
    }

    @Test func periodSymptomIsAttributedToMenstrualPhase() {
        var f = Fixture()
        // Cramps on day 1-2 of each of the three completed cycles.
        for start in f.starts.prefix(3) {
            f.symptomsByDay[start] = [.abdominalCramps]
            f.symptomsByDay[addDays(start, 1)] = [.abdominalCramps]
        }
        let insights = f.insights()
        #expect(insights.contains { $0.text.contains("cramps") && $0.text.contains("period") })
    }

    @Test func prePeriodSymptomGetsLeadInsight() {
        var f = Fixture()
        // Cravings 2 days before each next start (days 26-27 of the cycle).
        for (index, start) in f.starts.prefix(3).enumerated() {
            let nextStart = f.starts[index + 1]
            f.symptomsByDay[addDays(nextStart, -2)] = [.cravings]
            _ = start
        }
        let insights = f.insights()
        #expect(insights.contains { $0.text.contains("cravings") && $0.text.contains("before your period") })
    }

    @Test func moodDipInLutealIsDetected() {
        var f = Fixture()
        // Pleasant follicular moods, unpleasant luteal moods, every completed cycle.
        for (index, start) in f.starts.prefix(3).enumerated() {
            let nextStart = f.starts[index + 1]
            f.moodByDay[addDays(start, 8)] = MoodEntry(valence: 0.6, labels: [])
            f.moodByDay[addDays(start, 10)] = MoodEntry(valence: 0.5, labels: [])
            f.moodByDay[addDays(nextStart, -4)] = MoodEntry(valence: -0.3, labels: [])
            f.moodByDay[addDays(nextStart, -2)] = MoodEntry(valence: -0.4, labels: [])
        }
        let insights = f.insights()
        #expect(insights.contains { $0.text.contains("mood") && $0.text.contains("dip") })
    }

    @Test func rareSymptomsAreIgnored() {
        var f = Fixture()
        // Only two headache logs ever — below the 3-occurrence floor.
        f.symptomsByDay[addDays(f.starts[0], 20)] = [.headache]
        f.symptomsByDay[addDays(f.starts[1], 20)] = [.headache]
        let insights = f.insights()
        #expect(!insights.contains { $0.text.contains("headache") })
    }

    @Test func capAtFourInsights() {
        var f = Fixture()
        // Blanket-log five symptoms during every period + mood dip data.
        for (index, start) in f.starts.prefix(3).enumerated() {
            let nextStart = f.starts[index + 1]
            for offset in 0..<3 {
                f.symptomsByDay[addDays(start, offset)] = [.abdominalCramps, .headache, .fatigue, .bloating, .nausea]
            }
            f.moodByDay[addDays(start, 8)] = MoodEntry(valence: 0.6, labels: [])
            f.moodByDay[addDays(start, 10)] = MoodEntry(valence: 0.5, labels: [])
            f.moodByDay[addDays(nextStart, -4)] = MoodEntry(valence: -0.4, labels: [])
            f.moodByDay[addDays(nextStart, -2)] = MoodEntry(valence: -0.5, labels: [])
        }
        #expect(f.insights().count <= 4)
    }
}

@Suite struct CompanionTipsTests {
    @Test func everyPhaseAndDayHasATip() {
        for phase in [CyclePhase.menstrual, .follicular, .ovulatory, .luteal] {
            for cycleDay in 1...35 {
                #expect(!CompanionTips.tip(for: phase, cycleDay: cycleDay).isEmpty)
            }
        }
    }

    @Test func tipIsStableForAGivenDay() {
        let a = CompanionTips.tip(for: .luteal, cycleDay: 24)
        let b = CompanionTips.tip(for: .luteal, cycleDay: 24)
        #expect(a == b)
    }

    @Test func tipsRotateAcrossDays() {
        let tips = Set((1...6).map { CompanionTips.tip(for: .follicular, cycleDay: $0) })
        #expect(tips.count > 1)
    }
}
