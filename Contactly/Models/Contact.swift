import Foundation
import SwiftUI

enum RelationshipType: String, Codable, CaseIterable {
    case pro
    case perso

    var sortOrder: Int {
        switch self {
        case .perso:
            return 0
        case .pro:
            return 1
        }
    }

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

enum ImportantInfoType: String, Codable, CaseIterable, Hashable, Identifiable {
    case birthday
    case interest
    case spouse
    case children

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .birthday:
            return "Birthday"
        case .interest:
            return "Interest"
        case .spouse:
            return "Spouse"
        case .children:
            return "Children"
        }
    }
}

struct ImportantInfo: Codable, Hashable, Identifiable {
    var id: UUID
    var type: ImportantInfoType
    var value: String

    init(id: UUID = UUID(), type: ImportantInfoType, value: String) {
        self.id = id
        self.type = type
        self.value = value
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
    var birthday: Date?
    var lastInteractionDate: Date?
    var relationshipType: RelationshipType
    var importantInformation: [ImportantInfo]

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
        birthday: Date? = nil,
        lastInteractionDate: Date? = nil,
        relationshipType: RelationshipType = .perso,
        importantInformation: [ImportantInfo] = []
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
        self.birthday = birthday
        self.lastInteractionDate = lastInteractionDate
        self.relationshipType = relationshipType
        self.importantInformation = importantInformation
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
        case birthday
        case lastInteractionDate
        case relationshipType
        case importantInformation
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
        birthday = try container.decodeIfPresent(Date.self, forKey: .birthday)
        lastInteractionDate = try container.decodeIfPresent(Date.self, forKey: .lastInteractionDate)
        let storedRelationship = try container.decodeIfPresent(String.self, forKey: .relationshipType)
        relationshipType = RelationshipType.fromStoredValue(storedRelationship)
        importantInformation = try container.decodeIfPresent([ImportantInfo].self, forKey: .importantInformation) ?? []

        // Backward compatibility: hydrate the new field from legacy birthday important info if needed.
        if birthday == nil,
           let legacyBirthday = importantInformation.first(where: { $0.type == .birthday })?.value
        {
            birthday = Self.legacyBirthdayFormatter.date(from: legacyBirthday)
        }
    }

    private static var legacyBirthdayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
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

extension Contact {
    func lastInteractionDate(from interactions: [Interaction]) -> Date? {
        interactions
            .filter { $0.contactId == id }
            .map(\.date)
            .sorted(by: >)
            .first
    }

    func daysSinceLastInteraction(from interactions: [Interaction], now: Date = Date()) -> Int? {
        guard let lastDate = lastInteractionDate(from: interactions) else { return nil }
        return Calendar.current.dateComponents([.day], from: lastDate, to: now).day
    }

    func interactionFrequencyDays(from interactions: [Interaction]) -> Int? {
        let sorted = interactions
            .filter { $0.contactId == id }
            .map(\.date)
            .sorted()

        guard sorted.count >= 2, let first = sorted.first, let last = sorted.last else {
            return nil
        }

        let totalDays = Calendar.current.dateComponents([.day], from: first, to: last).day ?? 0
        return totalDays / (sorted.count - 1)
    }
}
