import Foundation

struct ReminderSettings: Codable, Equatable {
    var delayMinutes: Int
    var calendarAccessGranted: Bool
    var notificationsEnabled: Bool
    var quietHours: QuietHours
    var calendarProviders: [CalendarProvider]

    static let `default` = ReminderSettings(
        delayMinutes: 15,
        calendarAccessGranted: false,
        notificationsEnabled: false,
        quietHours: .default,
        calendarProviders: []
    )

    private enum CodingKeys: String, CodingKey {
        case delayMinutes
        case calendarAccessGranted
        case notificationsEnabled
        case quietHours
        case calendarProviders
    }

    init(
        delayMinutes: Int,
        calendarAccessGranted: Bool,
        notificationsEnabled: Bool,
        quietHours: QuietHours,
        calendarProviders: [CalendarProvider]
    ) {
        self.delayMinutes = delayMinutes
        self.calendarAccessGranted = calendarAccessGranted
        self.notificationsEnabled = notificationsEnabled
        self.quietHours = quietHours
        self.calendarProviders = calendarProviders
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        delayMinutes = try container.decodeIfPresent(Int.self, forKey: .delayMinutes) ?? Self.default.delayMinutes
        calendarAccessGranted = try container.decodeIfPresent(Bool.self, forKey: .calendarAccessGranted) ?? Self.default.calendarAccessGranted
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? Self.default.notificationsEnabled
        quietHours = try container.decodeIfPresent(QuietHours.self, forKey: .quietHours) ?? Self.default.quietHours
        calendarProviders = try container.decodeIfPresent([CalendarProvider].self, forKey: .calendarProviders) ?? []
    }
}
