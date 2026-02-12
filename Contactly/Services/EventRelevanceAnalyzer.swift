import Foundation

struct EventRelevanceAnalyzer {
    func relevantMeetings(
        from events: [SyncedCalendarEvent],
        contacts: [Contact],
        currentUserEmail: String
    ) -> [MeetingEvent] {
        let contactsByEmail = dictionaryByEmail(from: contacts)
        let normalizedCurrentUserEmail = normalizeEmail(currentUserEmail)

        let meetings = events.compactMap { event -> MeetingEvent? in
            let normalizedAttendees = Array(Set(event.attendeeEmails.map(normalizeEmail).filter { !$0.isEmpty })).sorted()
            guard normalizedAttendees.count > 1 else { return nil }

            let otherAttendees = normalizedAttendees.filter {
                normalizedCurrentUserEmail.isEmpty ? true : $0 != normalizedCurrentUserEmail
            }

            guard !otherAttendees.isEmpty else { return nil }

            let linkedContact = otherAttendees.compactMap { contactsByEmail[$0] }.first

            return MeetingEvent(
                id: event.id,
                title: event.title,
                startDate: event.startDate,
                endDate: event.endDate,
                linkedContact: linkedContact,
                attendeeEmails: otherAttendees
            )
        }

        return meetings
    }

    private func dictionaryByEmail(from contacts: [Contact]) -> [String: Contact] {
        var result: [String: Contact] = [:]

        for contact in contacts {
            let email = normalizeEmail(contact.email)
            if !email.isEmpty {
                result[email] = contact
            }
        }

        return result
    }

    private func normalizeEmail(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
