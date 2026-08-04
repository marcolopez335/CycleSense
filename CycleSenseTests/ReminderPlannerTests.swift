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

private func at9(_ y: Int, _ m: Int, _ d: Int) -> Date {
    utc.date(from: DateComponents(year: y, month: m, day: d, hour: 9))!
}

private func makePrediction(nextPeriod: Date, fertileStart: Date?) -> Prediction {
    Prediction(
        averageCycleLength: 28,
        averagePeriodLength: 5,
        nextPeriodStart: nextPeriod,
        upcomingPeriods: [],
        ovulationDate: nil,
        fertileWindow: fertileStart.map { DateInterval(start: $0, duration: 6 * 86400) }
    )
}

@Suite struct ReminderPlannerTests {
    @Test func fullSetWhenEverythingEnabledAndFuture() {
        let p = makePrediction(nextPeriod: day(2026, 8, 20), fertileStart: day(2026, 8, 9))
        let reminders = ReminderPlanner.reminders(
            for: p, periodEnabled: true, fertileEnabled: true,
            now: day(2026, 8, 1), calendar: utc
        )
        #expect(reminders.map(\.id) == ["fertile-start", "period-2d", "period-0d"])
        #expect(reminders.first { $0.id == "period-2d" }!.fireDate == at9(2026, 8, 18))
        #expect(reminders.first { $0.id == "period-0d" }!.fireDate == at9(2026, 8, 20))
        #expect(reminders.first { $0.id == "fertile-start" }!.fireDate == at9(2026, 8, 9))
    }

    @Test func disabledTogglesDropTheirReminders() {
        let p = makePrediction(nextPeriod: day(2026, 8, 20), fertileStart: day(2026, 8, 9))
        let periodOnly = ReminderPlanner.reminders(
            for: p, periodEnabled: true, fertileEnabled: false,
            now: day(2026, 8, 1), calendar: utc
        )
        #expect(periodOnly.map(\.id) == ["period-2d", "period-0d"])
        let none = ReminderPlanner.reminders(
            for: p, periodEnabled: false, fertileEnabled: false,
            now: day(2026, 8, 1), calendar: utc
        )
        #expect(none.isEmpty)
    }

    @Test func pastFireDatesAreSkipped() {
        // Period on Aug 20; "now" is Aug 19 at noon → the 2-days-before slot
        // (Aug 18, 09:00) is past and must be dropped; day-of remains.
        let now = utc.date(from: DateComponents(year: 2026, month: 8, day: 19, hour: 12))!
        let p = makePrediction(nextPeriod: day(2026, 8, 20), fertileStart: day(2026, 8, 9))
        let reminders = ReminderPlanner.reminders(
            for: p, periodEnabled: true, fertileEnabled: true,
            now: now, calendar: utc
        )
        #expect(reminders.map(\.id) == ["period-0d"])
    }

    @Test func missingFertileWindowGivesNoFertileReminder() {
        let p = makePrediction(nextPeriod: day(2026, 8, 20), fertileStart: nil)
        let reminders = ReminderPlanner.reminders(
            for: p, periodEnabled: true, fertileEnabled: true,
            now: day(2026, 8, 1), calendar: utc
        )
        #expect(!reminders.contains { $0.id == "fertile-start" })
    }
}
