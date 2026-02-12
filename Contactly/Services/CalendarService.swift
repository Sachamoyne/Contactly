import EventKit
import Foundation
import Observation

@Observable
@MainActor
final class CalendarService {
    private let store = EKEventStore()
    private(set) var events: [CalendarEvent] = []
    private(set) var accessGranted = false

    init() {
        refreshAuthorizationStatus()
    }

    var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    func refreshAuthorizationStatus() {
        switch authorizationStatus {
        case .fullAccess, .authorized:
            accessGranted = true
        case .writeOnly, .denied, .restricted, .notDetermined:
            accessGranted = false
        @unknown default:
            accessGranted = false
        }
    }

    func requestFullAccessToEvents() async -> Bool {
        switch authorizationStatus {
        case .fullAccess, .authorized:
            accessGranted = true
            return true
        case .denied, .restricted:
            accessGranted = false
            return false
        case .writeOnly, .notDetermined:
            do {
                let granted = try await store.requestFullAccessToEvents()
                accessGranted = granted
                return granted
            } catch {
                accessGranted = false
                return false
            }
        @unknown default:
            accessGranted = false
            return false
        }
    }

    func fetchTodayEvents() -> [CalendarEvent] {
        guard accessGranted else {
            events = []
            return []
        }

        let now = Date()
        guard let endDate = Calendar.current.date(byAdding: .hour, value: 24, to: now) else {
            events = []
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

    func fetchTodaySyncedEvents() -> [SyncedCalendarEvent] {
        guard accessGranted else { return [] }

        let now = Date()
        guard let endDate = Calendar.current.date(byAdding: .hour, value: 24, to: now) else {
            return []
        }

        let predicate = store.predicateForEvents(withStart: now, end: endDate, calendars: nil)
        let ekEvents = store.events(matching: predicate)

        return ekEvents.map { event in
            SyncedCalendarEvent(
                id: (event.eventIdentifier ?? UUID().uuidString),
                title: event.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                    ? event.title ?? "Meeting"
                    : "Meeting",
                startDate: event.startDate,
                endDate: event.endDate,
                attendeeEmails: attendeeEmails(from: event)
            )
        }
    }

    private func attendeeEmails(from event: EKEvent) -> [String] {
        let emails = (event.attendees ?? []).compactMap { attendee in
            normalizeEmail(from: attendee.url)
        }

        return Array(Set(emails)).sorted()
    }

    private func normalizeEmail(from url: URL?) -> String? {
        guard let value = url?.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }

        let lowered = value.lowercased()
        if lowered.hasPrefix("mailto:") {
            let email = String(lowered.dropFirst("mailto:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            return email.isEmpty ? nil : email
        }

        return lowered.contains("@") ? lowered : nil
    }
}
