import Foundation

/// A single planned local notification. Pure data — scheduling lives in
/// NotificationScheduler so this stays unit-testable.
struct PlannedReminder: Equatable {
    /// Stable identifier; re-scheduling replaces requests by these ids.
    let id: String
    let fireDate: Date
    let title: String
    let body: String
}

/// Turns a `Prediction` into the set of local reminders to schedule.
/// Deterministic and side-effect free.
enum ReminderPlanner {
    static let allIdentifiers = ["fertile-start", "period-2d", "period-0d"]
    /// Reminders fire at 09:00 local time.
    static let fireHour = 9

    static func reminders(
        for prediction: Prediction,
        periodEnabled: Bool,
        fertileEnabled: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [PlannedReminder] {
        var result: [PlannedReminder] = []

        func fireDate(onDay day: Date) -> Date? {
            calendar.date(bySettingHour: fireHour, minute: 0, second: 0, of: calendar.startOfDay(for: day))
        }

        if fertileEnabled, let windowStart = prediction.fertileWindow?.start,
           let date = fireDate(onDay: windowStart), date > now {
            result.append(PlannedReminder(
                id: "fertile-start",
                fireDate: date,
                title: "Fertile window opening",
                body: "Your estimated fertile window starts today."
            ))
        }

        if periodEnabled {
            if let twoBefore = calendar.date(byAdding: .day, value: -2, to: prediction.nextPeriodStart),
               let date = fireDate(onDay: twoBefore), date > now {
                result.append(PlannedReminder(
                    id: "period-2d",
                    fireDate: date,
                    title: "Period soon",
                    body: "Your period is estimated to start in 2 days."
                ))
            }
            if let date = fireDate(onDay: prediction.nextPeriodStart), date > now {
                result.append(PlannedReminder(
                    id: "period-0d",
                    fireDate: date,
                    title: "Period expected today",
                    body: "Your period is estimated to start today."
                ))
            }
        }

        return result
    }
}
