import UserNotifications
import Foundation

@MainActor
final class NotificationService: ObservableObject {
    private let center = UNUserNotificationCenter.current()
    private let settingsRepo: SettingsRepository

    @Published var isAuthorized = false

    init(settingsRepo: SettingsRepository = SettingsRepository()) {
        self.settingsRepo = settingsRepo
    }

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

    func scheduleReminders(for events: [CalendarEvent]) async {
        guard isAuthorized else { return }

        // Remove previously scheduled reminders
        center.removeAllPendingNotificationRequests()

        let reminderSettings = settingsRepo.load()

        for event in events {
            guard !event.isAllDay else { continue }

            let fireDate = event.startDate.addingTimeInterval(
                -Double(reminderSettings.delayMinutes * 60)
            )

            // Don't schedule if the fire date is in the past
            guard fireDate > Date() else { continue }

            // Don't schedule during quiet hours
            guard !reminderSettings.quietHours.contains(fireDate) else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Upcoming: \(event.title)"
            content.body = formatReminderBody(event: event, delayMinutes: reminderSettings.delayMinutes)
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

            do {
                try await center.add(request)
            } catch {
                // Silently skip failed notification; don't crash
            }
        }
    }

    private func formatReminderBody(event: CalendarEvent, delayMinutes: Int) -> String {
        var body = "Starts in \(delayMinutes) minutes"
        if let location = event.location, !location.isEmpty {
            body += " at \(location)"
        }
        return body
    }
}
