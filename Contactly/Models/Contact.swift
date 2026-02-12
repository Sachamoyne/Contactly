import Foundation

struct Contact: Codable, Identifiable {
    var id: UUID
    var firstName: String
    var lastName: String
    var company: String
    var email: String
    var phone: String
    var notes: String
    var tags: [String]
    var createdAt: Date

    var fullName: String {
        [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
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
        createdAt: Date = Date()
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.company = company
        self.email = email
        self.phone = phone
        self.notes = notes
        self.tags = tags
        self.createdAt = createdAt
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
