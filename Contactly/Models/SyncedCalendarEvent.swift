import Foundation

struct SyncedCalendarEvent: Hashable, Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let attendeeEmails: [String]
}
