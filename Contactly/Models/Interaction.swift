import Foundation

struct Interaction: Codable, Identifiable, Hashable {
    var id: UUID
    var contactId: UUID
    var eventId: String?
    var title: String
    var startDate: Date
    var endDate: Date
    var notes: String
    var createdAt: Date
    var followUpDate: Date?
    var tagsSnapshot: [String]

    init(
        id: UUID = UUID(),
        contactId: UUID,
        eventId: String? = nil,
        title: String,
        startDate: Date,
        endDate: Date,
        notes: String,
        createdAt: Date = Date(),
        followUpDate: Date? = nil,
        tagsSnapshot: [String] = []
    ) {
        self.id = id
        self.contactId = contactId
        self.eventId = eventId
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.createdAt = createdAt
        self.followUpDate = followUpDate
        self.tagsSnapshot = tagsSnapshot
    }
}

