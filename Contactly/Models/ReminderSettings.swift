import Foundation

struct ReminderSettings: Codable, Equatable {
    /// Minutes before an event to send the reminder
    var delayMinutes: Int
    var quietHours: QuietHours

    static let `default` = ReminderSettings(
        delayMinutes: 15,
        quietHours: QuietHours.default
    )
}

struct QuietHours: Codable, Equatable {
    var isEnabled: Bool
    /// Hour component (0-23) when quiet hours start
    var startHour: Int
    /// Minute component (0-59) when quiet hours start
    var startMinute: Int
    /// Hour component (0-23) when quiet hours end
    var endHour: Int
    /// Minute component (0-59) when quiet hours end
    var endMinute: Int

    static let `default` = QuietHours(
        isEnabled: false,
        startHour: 22,
        startMinute: 0,
        endHour: 7,
        endMinute: 0
    )

    func contains(_ date: Date) -> Bool {
        guard isEnabled else { return false }
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let timeValue = hour * 60 + minute
        let startValue = startHour * 60 + startMinute
        let endValue = endHour * 60 + endMinute

        if startValue <= endValue {
            // Same day range (e.g. 08:00 - 18:00)
            return timeValue >= startValue && timeValue < endValue
        } else {
            // Overnight range (e.g. 22:00 - 07:00)
            return timeValue >= startValue || timeValue < endValue
        }
    }
}
