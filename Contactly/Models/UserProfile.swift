import Foundation

enum ContactSyncOption: String, Codable, CaseIterable, Identifiable {
    case all
    case selected
    case none

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all:
            return "Sync all contacts"
        case .selected:
            return "Select specific contacts"
        case .none:
            return "No contact sync"
        }
    }
}

struct UserProfile: Codable, Equatable {
    var firstName: String
    var lastName: String
    var email: String
    var calendarProvider: CalendarProvider
    var contactSyncOption: ContactSyncOption

    static let empty = UserProfile(
        firstName: "",
        lastName: "",
        email: "",
        calendarProvider: .none,
        contactSyncOption: .none
    )
}
