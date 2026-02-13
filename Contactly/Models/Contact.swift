import Foundation
import SwiftUI

enum RelationshipType: String, Codable, CaseIterable {
    case pro
    case perso

    var displayName: String {
        switch self {
        case .pro:
            return "Professional"
        case .perso:
            return "Personal"
        }
    }

    var color: Color {
        switch self {
        case .pro:
            return AppColors.pro
        case .perso:
            return AppColors.personal
        }
    }

    static func fromStoredValue(_ value: String?) -> RelationshipType {
        guard let value else { return .perso }
        switch value {
        case "pro", "professional":
            return .pro
        case "perso", "personal", "friend", "family", "acquaintance", "other":
            return .perso
        default:
            return .perso
        }
    }
}

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
    var relationshipType: RelationshipType

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
        lastInteractionDate: Date? = nil,
        relationshipType: RelationshipType = .perso
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
        self.relationshipType = relationshipType
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case firstName
        case lastName
        case company
        case email
        case phone
        case notes
        case tags
        case avatarPath
        case createdAt
        case lastInteractionDate
        case relationshipType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        firstName = try container.decode(String.self, forKey: .firstName)
        lastName = try container.decode(String.self, forKey: .lastName)
        company = try container.decode(String.self, forKey: .company)
        email = try container.decode(String.self, forKey: .email)
        phone = try container.decode(String.self, forKey: .phone)
        notes = try container.decode(String.self, forKey: .notes)
        tags = try container.decode([String].self, forKey: .tags)
        avatarPath = try container.decodeIfPresent(String.self, forKey: .avatarPath)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastInteractionDate = try container.decodeIfPresent(Date.self, forKey: .lastInteractionDate)
        let storedRelationship = try container.decodeIfPresent(String.self, forKey: .relationshipType)
        relationshipType = RelationshipType.fromStoredValue(storedRelationship)
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
