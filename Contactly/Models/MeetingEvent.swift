import Foundation

struct MeetingEvent: Identifiable, Hashable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let linkedContact: Contact?
    let attendeeEmails: [String]
}
