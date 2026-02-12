import EventKit
import Foundation
import Observation

@Observable
final class CalendarService {
    private let store = EKEventStore()
    private(set) var events: [CalendarEvent] = []
    private(set) var accessGranted = false

    var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    func requestAccess() async -> Bool {
        do {
            let granted: Bool
            if #available(iOS 17.0, *) {
                granted = try await store.requestFullAccessToEvents()
            } else {
                granted = try await store.requestAccess(to: .event)
            }
            accessGranted = granted
            return granted
        } catch {
            accessGranted = false
            return false
        }
    }

    func fetchTodayEvents() -> [CalendarEvent] {
        guard accessGranted else { return [] }

        let now = Date()
        guard let endDate = Calendar.current.date(byAdding: .hour, value: 24, to: now) else {
            return []
        }

        let predicate = store.predicateForEvents(withStart: now, end: endDate, calendars: nil)
        let ekEvents = store.events(matching: predicate)

        let mapped = ekEvents.map { ek in
            CalendarEvent(
                title: ek.title ?? "",
                startDate: ek.startDate,
                endDate: ek.endDate,
                location: ek.location ?? ""
            )
        }
        events = mapped
        return mapped
    }
}
