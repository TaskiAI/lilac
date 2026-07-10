import Foundation
import UserNotifications

/// Schedules the optional daily "time to journal" reminder through the system
/// notification center. Local-only — no server, no usage-string needed. All
/// calls are safe to make repeatedly; enabling replaces any existing reminder.
enum ReminderScheduler {
    static let identifier = "lilac.daily.reminder"

    /// Ask for permission (no-op if already decided). Returns whether granted.
    @discardableResult
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        default:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        }
    }

    /// Schedule (or reschedule) the daily reminder at the given hour/minute.
    static func schedule(hour: Int, minute: Int) async {
        guard await requestAuthorization() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Time for your journal"
        content.body = "Take a quiet moment for yourself today."
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        try? await center.add(request)
    }

    /// Cancel the daily reminder.
    static func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
