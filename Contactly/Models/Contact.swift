import Foundation

struct Contact: Identifiable, Codable, Hashable {
    let id: UUID
    var firstName: String
    var lastName: String
    var company: String
    var phone: String
    var email: String
    var notes: String
    var tags: [String]
    var avatarPath: String?
    let createdAt: Date
    var lastInteractionDate: Date?

    var fullName: String {
        [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
    }

    var initials: String {
        let components = [firstName, lastName].filter { !$0.isEmpty }
        return components.compactMap { $0.first.map(String.init) }.joined()
    }

    init(
        id: UUID = UUID(),
        firstName: String = "",
        lastName: String = "",
        company: String = "",
        phone: String = "",
        email: String = "",
        notes: String = "",
        tags: [String] = [],
        avatarPath: String? = nil,
        createdAt: Date = Date(),
        lastInteractionDate: Date? = nil
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.company = company
        self.phone = phone
        self.email = email
        self.notes = notes
        self.tags = tags
        self.avatarPath = avatarPath
        self.createdAt = createdAt
        self.lastInteractionDate = lastInteractionDate
    }
}
