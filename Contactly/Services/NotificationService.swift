import Foundation
import Observation
import UserNotifications

@Observable
final class NotificationService {
    private let center = UNUserNotificationCenter.current()
    private(set) var isAuthorized = false

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            return granted
        } catch {
            isAuthorized = false
            return false
        }
    }

    func checkAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    func scheduleReminders(for events: [CalendarEvent], settings: ReminderSettings) async {
        guard isAuthorized else { return }

        center.removeAllPendingNotificationRequests()

        for event in events {
            let fireDate = event.startDate.addingTimeInterval(
                -Double(settings.delayMinutes * 60)
            )

            guard fireDate > Date() else { continue }
            guard !settings.quietHours.contains(fireDate) else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Upcoming: \(event.title)"
            content.body = formatBody(event: event, delayMinutes: settings.delayMinutes)
            content.sound = .default

            let triggerDate = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

            let request = UNNotificationRequest(
                identifier: "event-\(event.id)",
                content: content,
                trigger: trigger
            )

            try? await center.add(request)
        }
    }

    private func formatBody(event: CalendarEvent, delayMinutes: Int) -> String {
        var body = "Starts in \(delayMinutes) minutes"
        if !event.location.isEmpty {
            body += " at \(event.location)"
        }
        return body
    }
}
