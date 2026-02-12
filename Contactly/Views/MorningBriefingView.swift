import SwiftUI

private struct MorningBriefingItem: Identifiable {
    let id: String
    let meeting: MeetingEvent
    let contact: Contact
    let lastInteractionSummary: String?
}

struct MorningBriefingView: View {
    var calendarService: CalendarService
    var contactsViewModel: ContactsViewModel
    var interactionRepository: InteractionRepository

    @State private var items: [MorningBriefingItem] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.spacingLarge) {
                    Text("Good Morning")
                        .font(.largeTitle.weight(.bold))

                    Text("You have \(items.count) meetings today")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    if isLoading {
                        ProgressView("Loading briefing...")
                            .padding(.top, AppTheme.spacingSmall)
                    } else if items.isEmpty {
                        Text("No matched contacts found for today's meetings.")
                            .foregroundStyle(.secondary)
                            .padding(.top, AppTheme.spacingSmall)
                    } else {
                        ForEach(items) { item in
                            briefingCard(item)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppTheme.spacingMedium)
            }
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("Morning Briefing")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadBriefing()
            }
        }
    }

    private func briefingCard(_ item: MorningBriefingItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: AppTheme.spacingMedium) {
                AvatarView(contact: item.contact, size: 48)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.contact.fullName.isEmpty ? "Unknown Contact" : item.contact.fullName)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("\(item.meeting.startDate.formatted(date: .omitted, time: .shortened)) - \(item.meeting.endDate.formatted(date: .omitted, time: .shortened))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            if let summary = item.lastInteractionSummary, !summary.isEmpty {
                Text("Last discussed: \(summary)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(AppTheme.spacingMedium)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    @MainActor
    private func loadBriefing() async {
        isLoading = true
        defer { isLoading = false }

        calendarService.refreshAuthorizationStatus()
        guard calendarService.accessGranted else {
            items = []
            return
        }

        let synced = calendarService.fetchTodaySyncedEvents()
        let contacts = contactsViewModel.repository.contacts

        let meetings = synced.map {
            MeetingEvent(
                id: $0.id,
                title: $0.title,
                startDate: $0.startDate,
                endDate: $0.endDate,
                linkedContact: nil,
                attendeeEmails: $0.attendeeEmails
            )
        }

        items = meetings.compactMap { meeting in
            guard let contact = matchedContact(for: meeting, contacts: contacts) else { return nil }
            let last = interactionRepository.listByContact(contactId: contact.id).first
            let summary = last.map { summarize($0.notes) }
            return MorningBriefingItem(
                id: "\(meeting.id)-\(contact.id.uuidString)",
                meeting: meeting,
                contact: contact,
                lastInteractionSummary: summary
            )
        }
    }

    private func matchedContact(for meeting: MeetingEvent, contacts: [Contact]) -> Contact? {
        let attendeeMatch = contacts.first { contact in
            let email = contact.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !email.isEmpty else { return false }
            return meeting.attendeeEmails.contains(email)
        }
        if let attendeeMatch {
            return attendeeMatch
        }

        let title = meeting.title.lowercased()
        return contacts.first { contact in
            let fullName = contact.fullName.lowercased()
            if !fullName.isEmpty && title.contains(fullName) {
                return true
            }

            let tokens = [contact.firstName.lowercased(), contact.lastName.lowercased()]
            return tokens.contains { token in
                token.count >= 3 && title.contains(token)
            }
        }
    }

    private func summarize(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.count <= 80 {
            return trimmed
        }
        let index = trimmed.index(trimmed.startIndex, offsetBy: 80)
        return "\(trimmed[..<index])..."
    }
}

