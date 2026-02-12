import Foundation

struct ManualMeeting: Codable, Identifiable, Hashable {
    var id: UUID
    var contactID: UUID
    var date: Date
    var occasion: String
    var notes: String

    init(
        id: UUID = UUID(),
        contactID: UUID,
        date: Date,
        occasion: String,
        notes: String = ""
    ) {
        self.id = id
        self.contactID = contactID
        self.date = date
        self.occasion = occasion
        self.notes = notes
    }
}
