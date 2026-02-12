import Foundation

struct Contact: Codable, Hashable, Identifiable {
    var id: UUID
    var firstName: String
    var lastName: String
    var company: String
    var email: String
    var phone: String
    var notes: String
    var tags: [String]
    var avatarPath: String?
    var createdAt: Date
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
        email: String = "",
        phone: String = "",
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
        self.email = email
        self.phone = phone
        self.notes = notes
        self.tags = tags
        self.avatarPath = avatarPath
        self.createdAt = createdAt
        self.lastInteractionDate = lastInteractionDate
    }

    static let preview = Contact(
        firstName: "Alice",
        lastName: "Martin",
        company: "Acme Corp",
        email: "alice@acme.com",
        phone: "+33 6 12 34 56 78",
        notes: "Met at the conference in Paris.",
        tags: ["client", "tech"]
    )

    static let previewList: [Contact] = [
        Contact(firstName: "Alice", lastName: "Martin", company: "Acme Corp", email: "alice@acme.com", tags: ["client"]),
        Contact(firstName: "Bob", lastName: "Dupont", company: "StartupX", email: "bob@startupx.io", tags: ["partner"]),
        Contact(firstName: "Clara", lastName: "Leroy", company: "DesignStudio", email: "clara@design.co", tags: ["freelance", "design"]),
        Contact(firstName: "David", lastName: "Chen", company: "TechGlobal", email: "david@techglobal.com", tags: ["investor"]),
        Contact(firstName: "Emma", lastName: "Bernard", company: "MediaGroup", email: "emma@media.fr", tags: ["press"]),
    ]
}
