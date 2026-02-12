import Foundation

struct ReminderSettings: Codable {
    var delayMinutes: Int
    var calendarAccessGranted: Bool
    var notificationsEnabled: Bool

    static let `default` = ReminderSettings(
        delayMinutes: 15,
        calendarAccessGranted: false,
        notificationsEnabled: false
    )
}
