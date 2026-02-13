import Foundation

enum CalendarProvider: String, Codable, CaseIterable, Hashable, Identifiable {
    case apple
    case google
    case none

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .apple:
            return "Apple Calendar"
        case .google:
            return "Google Calendar"
        case .none:
            return "No Calendar Sync"
        }
    }
}
