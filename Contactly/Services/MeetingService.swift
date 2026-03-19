import Foundation

@MainActor
final class MeetingService {
    private let calendarService: CalendarService
    private let googleCalendarService: GoogleCalendarService
    private let userProfileStore: UserProfileStore
    private let settingsRepository: SettingsRepository
    private let contactRepository: ContactRepository
    private let manualMeetingRepository: ManualMeetingRepository
    private let interactionRepository: InteractionRepository
    private let postMeetingNotificationService: PostMeetingNotificationService
    private let analyzer = EventRelevanceAnalyzer()

    init(
        calendarService: CalendarService,
        googleCalendarService: GoogleCalendarService,
        userProfileStore: UserProfileStore,
        settingsRepository: SettingsRepository,
        contactRepository: ContactRepository,
        manualMeetingRepository: ManualMeetingRepository,
        interactionRepository: InteractionRepository,
        postMeetingNotificationService: PostMeetingNotificationService
    ) {
        self.calendarService = calendarService
        self.googleCalendarService = googleCalendarService
        self.userProfileStore = userProfileStore
        self.settingsRepository = settingsRepository
        self.contactRepository = contactRepository
        self.manualMeetingRepository = manualMeetingRepository
        self.interactionRepository = interactionRepository
        self.postMeetingNotificationService = postMeetingNotificationService
    }

    var isCalendarAccessDenied: Bool {
        guard userProfileStore.profile.calendarProvider == .apple else { return false }
        calendarService.refreshAuthorizationStatus()
        return !calendarService.accessGranted
    }

    func syncMeetingEvents(for date: Date = Date()) async throws -> [MeetingEvent] {
        var allEvents: [SyncedCalendarEvent] = []

        for provider in activeProviders() {
            switch provider {
            case .none:
                continue
            case .apple:
                calendarService.refreshAuthorizationStatus()
                if calendarService.accessGranted {
                    allEvents.append(contentsOf: calendarService.fetchTodaySyncedEvents())
                }
            case .google:
                do {
                    let googleEvents = try await googleCalendarService.fetchUpcomingSyncedEvents(from: date, daysAhead: 1)
                    allEvents.append(contentsOf: googleEvents)
                    syncGoogleCalendarInteractions(from: googleEvents)
                } catch {
                    if isRecoverableCalendarSyncError(error) {
                        continue
                    }
                    throw error
                }
            }
        }

        let meetings = analyzer.relevantMeetings(
            from: allEvents,
            contacts: contactRepository.contacts,
            currentUserEmail: currentUserEmail()
        )

        return deduplicatedAndSorted(meetings)
    }

    func manualMeetings(for date: Date = Date()) -> [ManualMeeting] {
        manualMeetingRepository.meetings(on: date)
    }

    func addManualMeeting(contactID: UUID, date: Date, occasion: String, notes: String) {
        let meeting = ManualMeeting(
            contactID: contactID,
            date: date,
            occasion: occasion.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        manualMeetingRepository.add(meeting)
    }

    func updateManualMeeting(_ meeting: ManualMeeting) {
        manualMeetingRepository.update(meeting)
    }

    func deleteManualMeeting(_ meeting: ManualMeeting) {
        manualMeetingRepository.delete(meeting)
    }

    func contact(for manualMeeting: ManualMeeting) -> Contact? {
        contactRepository.contacts.first(where: { $0.id == manualMeeting.contactID })
    }

    private func currentUserEmail() -> String {
        switch userProfileStore.profile.calendarProvider {
        case .google:
            if !googleCalendarService.accountEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return googleCalendarService.accountEmail
            }
        case .apple, .none:
            break
        }

        return userProfileStore.profile.email
    }

    private func activeProviders() -> [CalendarProvider] {
        let configured = settingsRepository.settings.calendarProviders.filter { $0 != .none }
        if configured.isEmpty {
            let selected = userProfileStore.profile.calendarProvider
            return selected == .none ? [] : [selected]
        }
        return configured
    }

    private func deduplicatedAndSorted(_ meetings: [MeetingEvent]) -> [MeetingEvent] {
        let sorted = meetings.sorted { $0.startDate < $1.startDate }
        var seen = Set<String>()
        var unique: [MeetingEvent] = []

        for meeting in sorted {
            let key = "\(meeting.title.lowercased())|\(meeting.startDate.timeIntervalSince1970)"
            if seen.contains(key) {
                continue
            }
            seen.insert(key)
            unique.append(meeting)
        }

        return unique
    }

    private func isRecoverableCalendarSyncError(_ error: Error) -> Bool {
        guard let calendarError = error as? GoogleCalendarServiceError else { return false }
        switch calendarError {
        case .notSignedIn, .unauthorized, .tokenMissing:
            return true
        default:
            return false
        }
    }

    private func syncGoogleCalendarInteractions(from events: [SyncedCalendarEvent]) {
        let currentEmail = normalizeEmail(currentUserEmail())
        let contactsByEmail = Dictionary(
            uniqueKeysWithValues: contactRepository.contacts.compactMap { contact -> (String, Contact)? in
                let email = normalizeEmail(contact.email)
                guard !email.isEmpty else { return nil }
                return (email, contact)
            }
        )

        for event in events {
            let attendees = Set(event.attendeeEmails.map(normalizeEmail).filter { !$0.isEmpty })
            let nonSelfAttendees = attendees.filter { attendee in
                currentEmail.isEmpty || attendee != currentEmail
            }

            for attendee in nonSelfAttendees {
                guard let contact = contactsByEmail[attendee] else { continue }
                if !interactionRepository.hasInteraction(contactId: contact.id, eventId: event.id, date: event.startDate) {
                    let interaction = Interaction(
                        contactId: contact.id,
                        type: .meeting,
                        date: event.startDate,
                        eventId: event.id,
                        title: "Meeting (Google Calendar)",
                        metadata: ["calendarEventId": event.id],
                        startDate: event.startDate,
                        endDate: event.endDate,
                        notes: "",
                        tagsSnapshot: contact.tags
                    )
                    interactionRepository.add(interaction)
                }

                postMeetingNotificationService.schedulePostMeetingNote(
                    contactId: contact.id,
                    contactName: contact.fullName.isEmpty ? "this contact" : contact.fullName,
                    eventId: event.id,
                    meetingEndDate: event.endDate
                )
            }
        }
    }

    private func normalizeEmail(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
