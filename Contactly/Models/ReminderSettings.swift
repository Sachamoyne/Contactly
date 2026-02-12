import Foundation

struct ReminderSettings: Codable, Equatable {
    var delayMinutes: Int
    var calendarAccessGranted: Bool
    var notificationsEnabled: Bool
    var quietHours: QuietHours

    static let `default` = ReminderSettings(
        delayMinutes: 15,
        calendarAccessGranted: false,
        notificationsEnabled: false,
        quietHours: .default
    )
}
