import Foundation
import UserNotifications

/// Thin wrapper around UNUserNotificationCenter: replaces the app's pending
/// cycle reminders with a freshly planned set.
enum NotificationScheduler {
    /// UserDefaults keys for the Settings toggles. CycleStore reads them too.
    static let periodEnabledKey = "periodReminderEnabled"
    static let fertileEnabledKey = "fertileReminderEnabled"

    /// Asks for alert/sound permission. Returns whether it is granted.
    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func permissionDenied() async -> Bool {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
    }

    /// Replaces all cycle reminders with the given plan.
    static func apply(_ reminders: [PlannedReminder], calendar: Calendar = .current) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ReminderPlanner.allIdentifiers)
        for reminder in reminders {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    /// Plans from the current prediction + toggle state, then applies.
    static func reschedule(prediction: Prediction?, defaults: UserDefaults = .standard) async {
        let periodEnabled = defaults.bool(forKey: periodEnabledKey)
        let fertileEnabled = defaults.bool(forKey: fertileEnabledKey)
        guard let prediction, periodEnabled || fertileEnabled else {
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: ReminderPlanner.allIdentifiers)
            return
        }
        let planned = ReminderPlanner.reminders(
            for: prediction,
            periodEnabled: periodEnabled,
            fertileEnabled: fertileEnabled
        )
        await apply(planned)
    }
}
