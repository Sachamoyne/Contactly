import Foundation
import Observation

@Observable
final class CalendarService {
    private(set) var accessGranted = false

    func requestAccess() async -> Bool {
        // Stub: In production, use EKEventStore.requestFullAccessToEvents()
        accessGranted = true
        return true
    }

    func fetchTodayEvents() -> [CalendarEvent] {
        // Stub: Returns mock data for development
        CalendarEvent.previewList
    }
}
