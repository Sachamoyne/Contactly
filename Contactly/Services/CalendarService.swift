import EventKit
import Foundation
import Observation

@Observable
@MainActor
final class CalendarService {
    private let store = EKEventStore()
    private var pendingRefreshTask: Task<Void, Never>?
    private var lastEventsFingerprint: String = ""

    private(set) var events: [CalendarEvent] = []
    private(set) var accessGranted = false

    init() {
        refreshAuthorizationStatus()
        registerEventStoreObserver()
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .EKEventStoreChanged, object: nil)
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

    func fetchTodayEvents() async throws -> [CalendarEvent] {
        refreshAuthorizationStatus()

        guard accessGranted else {
            events = []
            lastEventsFingerprint = ""
            return []
        }

        let mapped = todayEventsSnapshot()
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

    private func registerEventStoreObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEventStoreChangedNotification),
            name: .EKEventStoreChanged,
            object: nil
        )
    }

    private func scheduleRefreshAfterStoreChange() {
        pendingRefreshTask?.cancel()
        pendingRefreshTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.handleEventStoreChange()
            }
        }
    }

    @objc private func handleEventStoreChangedNotification() {
        scheduleRefreshAfterStoreChange()
    }

    private func handleEventStoreChange() {
        refreshAuthorizationStatus()

        guard accessGranted else {
            let hadEvents = !events.isEmpty
            events = []
            if hadEvents {
                notifyEventsDidChange()
            }
            return
        }

        let previousFingerprint = lastEventsFingerprint
        let refreshedEvents = todayEventsSnapshot()
        let currentFingerprint = fingerprint(for: refreshedEvents)
        events = refreshedEvents
        lastEventsFingerprint = currentFingerprint
        if currentFingerprint != previousFingerprint {
            notifyEventsDidChange()
            return
        }

        notifyEventsDidChange()
    }

    private func notifyEventsDidChange() {
        NotificationCenter.default.post(name: .calendarServiceEventsDidChange, object: nil)
    }

    private func fingerprint(for events: [CalendarEvent]) -> String {
        events
            .map { "\($0.title)|\($0.startDate.timeIntervalSince1970)|\($0.endDate.timeIntervalSince1970)|\($0.location)" }
            .joined(separator: "#")
    }

    private func todayEventsSnapshot() -> [CalendarEvent] {
        let now = Date()
        guard let endDate = Calendar.current.date(byAdding: .hour, value: 24, to: now) else {
            return []
        }

        let predicate = store.predicateForEvents(withStart: now, end: endDate, calendars: nil)
        let ekEvents = store.events(matching: predicate)

        return ekEvents.map { ek in
            CalendarEvent(
                title: ek.title ?? "",
                startDate: ek.startDate,
                endDate: ek.endDate,
                location: ek.location ?? ""
            )
        }
    }
}

extension Notification.Name {
    static let calendarServiceEventsDidChange = Notification.Name("CalendarServiceEventsDidChange")
}
