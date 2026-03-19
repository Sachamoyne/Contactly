import Foundation
import Observation
import UserNotifications

@Observable
final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private(set) var isAuthorized = false
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private let morningBriefingIdentifierPrefix = "morning-briefing-"
    private let birthdayIdentifierPrefix = "birthday-"

    func requestAuthorization() async -> Bool {
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await checkAuthorizationStatus()
            return isAuthorized
        } catch {
            isAuthorized = false
            authorizationStatus = .denied
            return false
        }
    }

    func checkAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        isAuthorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    func scheduleReminders(for events: [CalendarEvent], settings: ReminderSettings) async {
        guard isAuthorized else { return }

        let pending = await center.pendingNotificationRequests()
        let eventReminderIDs = pending
            .map(\.identifier)
            .filter { $0.hasPrefix("event-") }
        if !eventReminderIDs.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: eventReminderIDs)
        }

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

    @MainActor
    func scheduleMorningBriefing(calendarService: CalendarService) async {
        await checkAuthorizationStatus()
        guard isAuthorized else { return }

        calendarService.refreshAuthorizationStatus()
        guard calendarService.accessGranted else { return }

        let todaysEvents = (try? await calendarService.fetchTodayEvents()) ?? []
        guard !todaysEvents.isEmpty else {
            await removeTodayMorningBriefingIfNeeded()
            return
        }

        let now = Date()
        guard let todayAtEight = Calendar.current.date(
            bySettingHour: 8,
            minute: 0,
            second: 0,
            of: now
        ) else { return }

        if now >= todayAtEight {
            return
        }

        let todayID = morningBriefingIdentifier(for: now)

        let pending = await center.pendingNotificationRequests()
        if pending.contains(where: { $0.identifier == todayID }) {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Today's Meetings"
        content.body = "You have \(todaysEvents.count) meetings today. Open to prepare."
        content.sound = .default
        content.userInfo = ["type": "morningBriefing"]

        let components = Calendar.current.dateComponents([.year, .month, .day], from: now)
        let triggerDate = DateComponents(
            year: components.year,
            month: components.month,
            day: components.day,
            hour: 8,
            minute: 0
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let request = UNNotificationRequest(
            identifier: todayID,
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
    }

    private func formatBody(event: CalendarEvent, delayMinutes: Int) -> String {
        var body = "Starts in \(delayMinutes) minutes"
        if !event.location.isEmpty {
            body += " at \(event.location)"
        }
        return body
    }

    private func morningBriefingIdentifier(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(morningBriefingIdentifierPrefix)\(formatter.string(from: date))"
    }

    private func removeTodayMorningBriefingIfNeeded() async {
        let todayID = morningBriefingIdentifier(for: Date())
        let pending = await center.pendingNotificationRequests()
        if pending.contains(where: { $0.identifier == todayID }) {
            center.removePendingNotificationRequests(withIdentifiers: [todayID])
        }
    }

    func scheduleBirthdayNotification(for contact: Contact) {
        let identifier = birthdayNotificationIdentifier(for: contact.id)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])

        guard let birthday = contact.birthday else { return }

        let calendar = Calendar.current
        let components = calendar.dateComponents([.day, .month], from: birthday)
        guard let day = components.day, let month = components.month else { return }

        var triggerDate = DateComponents()
        triggerDate.day = day
        triggerDate.month = month
        triggerDate.hour = 8
        triggerDate.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: true)

        let displayName = contact.fullName.isEmpty ? "this contact" : contact.fullName
        let content = UNMutableNotificationContent()
        content.title = "Birthday"
        content.body = "Today is \(displayName)'s birthday."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    func removeBirthdayNotification(for contactID: UUID) {
        let identifier = birthdayNotificationIdentifier(for: contactID)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    func syncBirthdayNotifications(for contacts: [Contact]) {
        let validIDs = Set(contacts.map(\.id).map(birthdayNotificationIdentifier(for:)))
        center.getPendingNotificationRequests { [center] requests in
            let staleIDs = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(self.birthdayIdentifierPrefix) && !validIDs.contains($0) }

            if !staleIDs.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: staleIDs)
                center.removeDeliveredNotifications(withIdentifiers: staleIDs)
            }
        }

        for contact in contacts {
            scheduleBirthdayNotification(for: contact)
        }
    }

    private func birthdayNotificationIdentifier(for contactID: UUID) -> String {
        "\(birthdayIdentifierPrefix)\(contactID.uuidString)"
    }
}
