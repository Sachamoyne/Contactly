import Foundation

struct CalendarEvent: Codable, Identifiable {
    var id: UUID
    var title: String
    var startDate: Date
    var endDate: Date
    var location: String
    var contactId: UUID?

    init(
        id: UUID = UUID(),
        title: String,
        startDate: Date,
        endDate: Date,
        location: String = "",
        contactId: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.contactId = contactId
    }

    static let preview: CalendarEvent = {
        let start = Calendar.current.date(bySettingHour: 14, minute: 30, second: 0, of: Date())!
        let end = Calendar.current.date(byAdding: .hour, value: 1, to: start)!
        return CalendarEvent(title: "Product Review", startDate: start, endDate: end, location: "Room 3B")
    }()

    static let previewList: [CalendarEvent] = {
        let calendar = Calendar.current
        let today = Date()
        return [
            CalendarEvent(
                title: "Team Standup",
                startDate: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: today)!,
                endDate: calendar.date(bySettingHour: 9, minute: 15, second: 0, of: today)!,
                location: "Zoom"
            ),
            CalendarEvent(
                title: "Product Review",
                startDate: calendar.date(bySettingHour: 10, minute: 30, second: 0, of: today)!,
                endDate: calendar.date(bySettingHour: 11, minute: 30, second: 0, of: today)!,
                location: "Room 3B"
            ),
            CalendarEvent(
                title: "Lunch with Alice",
                startDate: calendar.date(bySettingHour: 12, minute: 0, second: 0, of: today)!,
                endDate: calendar.date(bySettingHour: 13, minute: 0, second: 0, of: today)!,
                location: "Le Cafe"
            ),
            CalendarEvent(
                title: "Design Sprint",
                startDate: calendar.date(bySettingHour: 14, minute: 0, second: 0, of: today)!,
                endDate: calendar.date(bySettingHour: 16, minute: 0, second: 0, of: today)!,
                location: "Creative Lab"
            ),
            CalendarEvent(
                title: "Investor Call",
                startDate: calendar.date(bySettingHour: 17, minute: 0, second: 0, of: today)!,
                endDate: calendar.date(bySettingHour: 17, minute: 45, second: 0, of: today)!,
                location: "Phone"
            ),
        ]
    }()
}
