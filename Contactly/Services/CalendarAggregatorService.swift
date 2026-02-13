import Foundation
import Observation

@Observable
@MainActor
final class CalendarAggregatorService {
    private let appleService: CalendarService
    private let googleService: GoogleCalendarService
    private let userProfileStore: UserProfileStore

    private(set) var events: [CalendarEvent] = []
    private(set) var lastErrorMessage: String?

    init(
        appleService: CalendarService,
        googleService: GoogleCalendarService,
        userProfileStore: UserProfileStore
    ) {
        self.appleService = appleService
        self.googleService = googleService
        self.userProfileStore = userProfileStore
    }

    func fetchTodayEvents() async -> [CalendarEvent] {
        lastErrorMessage = nil

        switch userProfileStore.profile.calendarProvider {
        case .none:
            events = []
            return []

        case .apple:
            appleService.refreshAuthorizationStatus()
            guard appleService.accessGranted else {
                events = []
                return []
            }

            do {
                let appleEvents = try await appleService.fetchTodayEvents()
                events = deduplicatedAndSorted(appleEvents)
                return events
            } catch {
                events = []
                lastErrorMessage = "Unable to fetch Apple Calendar events."
                return []
            }

        case .google:
            do {
                let googleEvents = try await googleService.fetchUpcomingEvents(daysAhead: 1)
                events = deduplicatedAndSorted(googleEvents)
                return events
            } catch {
                events = []
                if let description = (error as? LocalizedError)?.errorDescription {
                    lastErrorMessage = description
                } else {
                    lastErrorMessage = "Unable to fetch Google Calendar events."
                }
                return []
            }
        }
    }

    private func deduplicatedAndSorted(_ events: [CalendarEvent]) -> [CalendarEvent] {
        let sorted = events.sorted { $0.startDate < $1.startDate }
        var seen = Set<String>()
        var unique: [CalendarEvent] = []

        for event in sorted {
            let key = "\(event.title.lowercased())|\(event.startDate.timeIntervalSince1970)"
            if seen.contains(key) {
                continue
            }
            seen.insert(key)
            unique.append(event)
        }

        return unique
    }
}
