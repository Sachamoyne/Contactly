import Foundation

enum InteractionType: String, Codable, Hashable, CaseIterable {
    case meeting = "MEETING"
    case note = "NOTE"
    case call = "CALL"
    case message = "MESSAGE"
    case other = "OTHER"

    var displayName: String {
        switch self {
        case .meeting:
            return "Meeting"
        case .note:
            return "Note"
        case .call:
            return "Call"
        case .message:
            return "Message"
        case .other:
            return "Other"
        }
    }
}

struct Interaction: Codable, Identifiable, Hashable {
    var id: UUID
    var contactId: UUID
    var type: InteractionType
    var date: Date
    var eventId: String?
    var title: String
    var metadata: [String: String]?
    var startDate: Date
    var endDate: Date
    var notes: String
    var createdAt: Date
    var followUpDate: Date?
    var tagsSnapshot: [String]

    init(
        id: UUID = UUID(),
        contactId: UUID,
        type: InteractionType = .other,
        date: Date? = nil,
        eventId: String? = nil,
        title: String,
        metadata: [String: String]? = nil,
        startDate: Date,
        endDate: Date,
        notes: String,
        createdAt: Date = Date(),
        followUpDate: Date? = nil,
        tagsSnapshot: [String] = []
    ) {
        self.id = id
        self.contactId = contactId
        self.type = type
        self.date = date ?? startDate
        self.eventId = eventId
        self.title = title
        self.metadata = metadata
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.createdAt = createdAt
        self.followUpDate = followUpDate
        self.tagsSnapshot = tagsSnapshot
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case contactId
        case type
        case date
        case eventId
        case title
        case metadata
        case startDate
        case endDate
        case notes
        case createdAt
        case followUpDate
        case tagsSnapshot
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        contactId = try container.decode(UUID.self, forKey: .contactId)
        eventId = try container.decodeIfPresent(String.self, forKey: .eventId)
        title = try container.decode(String.self, forKey: .title)
        metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        notes = try container.decode(String.self, forKey: .notes)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        followUpDate = try container.decodeIfPresent(Date.self, forKey: .followUpDate)
        tagsSnapshot = try container.decodeIfPresent([String].self, forKey: .tagsSnapshot) ?? []

        type = try container.decodeIfPresent(InteractionType.self, forKey: .type) ?? .other
        date = try container.decodeIfPresent(Date.self, forKey: .date) ?? startDate
    }
}
