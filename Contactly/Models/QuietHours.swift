import Foundation

struct QuietHours: Codable, Equatable {
    var isEnabled: Bool
    var startHour: Int
    var startMinute: Int
    var endHour: Int
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
            return timeValue >= startValue && timeValue < endValue
        } else {
            return timeValue >= startValue || timeValue < endValue
        }
    }
}
