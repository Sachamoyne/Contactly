import SwiftUI
import UIKit

private struct PrepContext: Identifiable {
    let meeting: MeetingEvent
    let contact: Contact

    var id: String {
        "\(meeting.id)-\(contact.id.uuidString)"
    }
}

private struct InteractionContext: Identifiable {
    let meeting: MeetingEvent
    let contact: Contact

    var id: String {
        "\(meeting.id)-\(contact.id.uuidString)-interaction"
    }
}

private struct PendingFollowUpItem: Identifiable {
    let interaction: Interaction
    let contact: Contact

    var id: UUID {
        interaction.id
    }
}

struct TodayView: View {
    var meetingService: MeetingService
    var contactsViewModel: ContactsViewModel
    var notificationService: NotificationService
    var settingsRepository: SettingsRepository
    var interactionRepository: InteractionRepository

    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: TodayViewModel
    @State private var showingErrorAlert = false
    @State private var showingManualMeetingSheet = false
    @State private var editingManualMeeting: ManualMeeting?
    @State private var prepContext: PrepContext?
    @State private var addInteractionContext: InteractionContext?
    @State private var afterMeetingPrompt: InteractionContext?
    @State private var promptedMeetingKeys: Set<String> = []
    @State private var createdContactForEditing: Contact?
    @State private var showingContactExistsAlert = false
    @State private var showingContactsFromEmptyState = false
    private let sectionSpacing: CGFloat = AppTheme.spacingLarge
    private let cardCornerRadius: CGFloat = AppTheme.cornerRadius

    init(
        meetingService: MeetingService,
        contactsViewModel: ContactsViewModel,
        notificationService: NotificationService,
        settingsRepository: SettingsRepository,
        interactionRepository: InteractionRepository
    ) {
        self.meetingService = meetingService
        self.contactsViewModel = contactsViewModel
        self.notificationService = notificationService
        self.settingsRepository = settingsRepository
        self.interactionRepository = interactionRepository
        _viewModel = StateObject(wrappedValue: TodayViewModel(meetingService: meetingService))
    }

    private var unifiedMeetings: [TodayViewModel.MeetingListItem] {
        var seen = Set<String>()
        return viewModel.sortedMeetings.filter { seen.insert($0.id).inserted }
    }

    private var primaryMeeting: TodayViewModel.MeetingListItem? {
        unifiedMeetings.first
    }

    private var remainingMeetings: [TodayViewModel.MeetingListItem] {
        Array(unifiedMeetings.dropFirst())
    }

    private var pendingFollowUps: [PendingFollowUpItem] {
        interactionRepository.getPendingFollowUps().compactMap { interaction in
            guard let contact = contactForInteraction(interaction) else { return nil }
            return PendingFollowUpItem(interaction: interaction, contact: contact)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: sectionSpacing) {
                followUpsSection
                todaysMeetingsSection
            }
            .padding(.horizontal, AppTheme.spacingMedium)
            .padding(.vertical, AppTheme.spacingMedium)
        }
        .background(Color(uiColor: .systemBackground))
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingManualMeetingSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(AppTheme.accent))
                }
                .buttonStyle(PressScaleButtonStyle())
                .disabled(contactsViewModel.repository.contacts.isEmpty)
            }
        }
        .navigationDestination(for: Contact.self) { contact in
            ContactView(
                contact: contact,
                viewModel: contactsViewModel,
                interactionRepository: interactionRepository
            )
        }
        .navigationDestination(isPresented: $showingContactsFromEmptyState) {
            ContactsListView(
                viewModel: contactsViewModel,
                interactionRepository: interactionRepository
            )
        }
        .sheet(isPresented: $showingManualMeetingSheet) {
            ManualMeetingCreationView(contacts: contactsViewModel.repository.contacts) { contactID, date, occasion, notes in
                Task {
                    await viewModel.createManualMeeting(contactID: contactID, date: date, occasion: occasion, notes: notes)
                }
            }
        }
        .sheet(item: $editingManualMeeting) { meeting in
            ManualMeetingCreationView(
                contacts: contactsViewModel.repository.contacts,
                existingMeeting: meeting,
                existingContact: viewModel.contact(for: meeting)
            ) { contactID, date, occasion, notes in
                Task {
                    var updated = meeting
                    updated.contactID = contactID
                    updated.date = date
                    updated.occasion = occasion
                    updated.notes = notes
                    await viewModel.updateManualMeeting(updated)
                }
            }
        }
        .sheet(item: $prepContext) { context in
            NavigationStack {
                PrepView(
                    meeting: context.meeting,
                    contact: context.contact,
                    interactionRepository: interactionRepository
                )
            }
        }
        .sheet(item: $addInteractionContext) { context in
            AddInteractionView(
                meeting: context.meeting,
                contact: context.contact,
                interactionRepository: interactionRepository
            ) {
                Task {
                    await refresh()
                }
            }
        }
        .sheet(item: $createdContactForEditing) { contact in
            EditContactView(viewModel: contactsViewModel, contact: contact)
        }
        .alert("Meeting Sync", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("Contact already exists", isPresented: $showingContactExistsAlert) {
            Button("OK", role: .cancel) { }
        }
        .alert(
            "Add meeting notes?",
            isPresented: Binding(
                get: { afterMeetingPrompt != nil },
                set: { newValue in
                    if !newValue {
                        afterMeetingPrompt = nil
                    }
                }
            )
        ) {
            Button("Later", role: .cancel) {
                afterMeetingPrompt = nil
            }
            Button("Add Notes") {
                if let prompt = afterMeetingPrompt {
                    addInteractionContext = prompt
                }
                afterMeetingPrompt = nil
            }
        } message: {
            Text("Add notes for your meeting with \(afterMeetingPrompt?.contact.fullName ?? "this contact")?")
        }
        .task {
            await refresh()
            evaluateAfterMeetingPrompt()
        }
        .refreshable {
            await refresh()
            evaluateAfterMeetingPrompt()
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            showingErrorAlert = newValue != nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .calendarServiceEventsDidChange)) { _ in
            Task {
                await refresh()
                evaluateAfterMeetingPrompt()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            evaluateAfterMeetingPrompt()
        }
    }

    private var followUpsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Follow Ups")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            if pendingFollowUps.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green.opacity(0.7))
                    Text("You're all caught up.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppTheme.spacingMedium)
                .background(
                    RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                        .fill(AppTheme.cardBackground)
                )
            } else {
                ForEach(pendingFollowUps) { item in
                    followUpRow(item)
                }
            }
        }
    }

    private var todaysMeetingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Meetings")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            if viewModel.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Refreshing meetings...")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if meetingService.isCalendarAccessDenied {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Calendar Access Disabled")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Enable calendar access to see upcoming meetings.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Enable Calendar") {
                        openAppSettings()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                    .buttonStyle(PressScaleButtonStyle())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppTheme.spacingMedium)
                .background(
                    RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                        .fill(AppTheme.cardBackground)
                )
            } else if let meeting = primaryMeeting {
                unifiedPrimaryMeetingCard(meeting)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No meetings today")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("A good day to reconnect.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Review Relationships") {
                        showingContactsFromEmptyState = true
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                    .buttonStyle(PressScaleButtonStyle())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppTheme.spacingMedium)
                .background(
                    RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                        .fill(AppTheme.cardBackground)
                )
            }

            if !remainingMeetings.isEmpty {
                VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                    Text("Upcoming")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    ForEach(remainingMeetings) { meeting in
                        unifiedMeetingRow(meeting)
                    }
                }
            }
        }
    }

    private func nextMeetingCard(_ meeting: MeetingEvent) -> some View {
        let matchedContact = contactForMeeting(meeting)

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: AppTheme.spacingMedium) {
                if let matchedContact {
                    AvatarView(contact: matchedContact, size: 80)
                } else {
                    Circle()
                        .fill(AppTheme.tintBackground)
                        .frame(width: 80, height: 80)
                        .overlay {
                            Text(String((meeting.attendeeEmails.first ?? "?").prefix(1)).uppercased())
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(AppTheme.accent)
                        }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(meeting.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text(matchedContact?.fullName.isEmpty == false ? (matchedContact?.fullName ?? "") : (meeting.attendeeEmails.first ?? "Unknown attendee"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text("\(meeting.startDate.formatted(date: .omitted, time: .shortened)) - \(meeting.endDate.formatted(date: .omitted, time: .shortened))")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            Text(notesSummary(for: matchedContact))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let matchedContact {
                HStack(spacing: 8) {
                    NavigationLink(value: matchedContact) {
                        Text("Review Contact")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(AppTheme.chipBackground))
                    }
                    .buttonStyle(.plain)

                    Button("Prep") {
                        prepContext = PrepContext(meeting: meeting, contact: matchedContact)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(AppTheme.chipBackground))
                    .buttonStyle(PressScaleButtonStyle())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Button("Create Contact") {
                    createContactFromMeeting(meeting)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Capsule().fill(AppTheme.chipBackground))
                .frame(maxWidth: .infinity, alignment: .leading)
                .buttonStyle(PressScaleButtonStyle())
            }
        }
        .padding(AppTheme.spacingLarge)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(AppTheme.tintBackground)
        )
        .shadow(color: .black.opacity(0.10), radius: 14, x: 0, y: 6)
        .fadeInOnAppear()
    }

    private func syncedMeetingRow(_ meeting: MeetingEvent) -> some View {
        let matchedContact = contactForMeeting(meeting)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: AppTheme.spacingSmall) {
                if let matchedContact {
                    AvatarView(contact: matchedContact, size: 44)
                } else {
                    Circle()
                        .fill(AppTheme.tintBackground)
                        .frame(width: 44, height: 44)
                        .overlay {
                            Text(String((meeting.attendeeEmails.first ?? "?").prefix(1)).uppercased())
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.accent)
                        }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(meeting.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(matchedContact?.fullName.isEmpty == false ? (matchedContact?.fullName ?? "") : (meeting.attendeeEmails.first ?? "Unknown attendee"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text("\(meeting.startDate.formatted(date: .omitted, time: .shortened)) - \(meeting.endDate.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }

            if let matchedContact {
                Button("Prep") {
                    prepContext = PrepContext(meeting: meeting, contact: matchedContact)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
                .buttonStyle(PressScaleButtonStyle())
            } else {
                Button("Create Contact") {
                    createContactFromMeeting(meeting)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
                .buttonStyle(PressScaleButtonStyle())
            }
        }
        .padding(AppTheme.spacingMedium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(AppTheme.cardBackground)
        )
        .fadeInOnAppear()
    }

    private func unifiedPrimaryMeetingCard(_ item: TodayViewModel.MeetingListItem) -> some View {
        switch item {
        case let .synced(meeting):
            return AnyView(nextMeetingCard(meeting))
        case let .manual(meeting):
            return AnyView(manualMeetingCard(meeting))
        }
    }

    private func unifiedMeetingRow(_ item: TodayViewModel.MeetingListItem) -> some View {
        switch item {
        case let .synced(meeting):
            return AnyView(syncedMeetingRow(meeting))
        case let .manual(meeting):
            return AnyView(manualMeetingRow(meeting))
        }
    }

    private func manualMeetingCard(_ meeting: ManualMeeting) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(viewModel.contact(for: meeting)?.fullName ?? "Unknown contact")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                Spacer()
                manualBadge
            }

            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.caption)
                Text(meeting.date, style: .time)
                    .font(.caption)
            }
            .foregroundStyle(.secondary)

            Text(meeting.occasion)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            if !meeting.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(meeting.notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(AppTheme.spacingLarge)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(AppTheme.tintBackground)
        )
        .shadow(color: .black.opacity(0.10), radius: 14, x: 0, y: 6)
        .fadeInOnAppear()
    }

    private func manualMeetingRow(_ meeting: ManualMeeting) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(viewModel.contact(for: meeting)?.fullName ?? "Unknown contact")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                manualBadge
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption)
                    Text(meeting.date, style: .time)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }

            Text(meeting.occasion)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            if !meeting.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(spacing: 4) {
                    Text(meeting.notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(AppTheme.spacingMedium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .fill(AppTheme.cardBackground)
        )
        .fadeInOnAppear()
    }

    private var manualBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "pencil")
                .font(.caption2)
            Text("Manual")
                .font(.caption2)
        }
        .foregroundStyle(.secondary)
    }

    private func followUpRow(_ item: PendingFollowUpItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: AppTheme.spacingSmall) {
                AvatarView(contact: item.contact, size: 42)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(colorForRelationshipStatus(relationshipStatus(for: item.contact).status))
                            .frame(width: 6, height: 6)

                        Text(item.contact.fullName.isEmpty ? "Unknown Contact" : item.contact.fullName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }

                    if let followUpDate = item.interaction.followUpDate {
                        Text("Follow-up: \(followUpDate.formatted(date: .abbreviated, time: .shortened))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }

            Text(notesPreview(item.interaction.notes))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 8) {
                NavigationLink(value: item.contact) {
                    Text("Open")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(AppTheme.chipBackground))
                }
                .buttonStyle(.plain)
                .buttonStyle(PressScaleButtonStyle())

                Button("Mark Done") {
                    markFollowUpDone(item.interaction)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(AppTheme.chipBackground))
                .buttonStyle(PressScaleButtonStyle())
            }
        }
        .padding(AppTheme.spacingMedium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .fill(AppTheme.cardBackground)
        )
        .fadeInOnAppear()
    }

    private func contactForMeeting(_ meeting: MeetingEvent) -> Contact? {
        if let linked = meeting.linkedContact {
            return linked
        }

        let contacts = contactsViewModel.repository.contacts
        let attendeeMatch = contacts.first(where: { contact in
            let email = contact.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !email.isEmpty else { return false }
            return meeting.attendeeEmails.contains(email)
        })
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

    private func notesSummary(for contact: Contact?) -> String {
        guard let contact else {
            return "Create or link a contact to keep meeting context in one place."
        }

        let note = contact.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if note.isEmpty {
            return "No notes stored for this contact."
        }

        if note.count <= 100 {
            return note
        }

        let index = note.index(note.startIndex, offsetBy: 100)
        return "\(note[..<index])..."
    }

    private func refresh() async {
        await viewModel.refresh()
        await scheduleNotifications()
    }

    private func scheduleNotifications() async {
        let reminderEvents = viewModel.meetingEvents.map { meeting in
            CalendarEvent(
                title: meeting.title,
                startDate: meeting.startDate,
                endDate: meeting.endDate
            )
        }

        await notificationService.checkAuthorizationStatus()
        guard notificationService.isAuthorized else {
            return
        }

        await notificationService.scheduleReminders(
            for: reminderEvents,
            settings: settingsRepository.settings
        )
    }

    private func evaluateAfterMeetingPrompt() {
        guard afterMeetingPrompt == nil else { return }

        let now = Date()
        let lowerBound = now.addingTimeInterval(-2 * 60 * 60)

        let candidate = viewModel.meetingEvents
            .filter { $0.endDate <= now && $0.endDate >= lowerBound }
            .compactMap { meeting -> InteractionContext? in
                guard let matched = contactForMeeting(meeting) else { return nil }

                if interactionRepository.hasInteraction(eventId: meeting.id, startDate: meeting.startDate) {
                    return nil
                }

                let key = promptKey(meeting: meeting, contact: matched)
                guard !promptedMeetingKeys.contains(key) else { return nil }

                return InteractionContext(meeting: meeting, contact: matched)
            }
            .sorted { $0.meeting.endDate > $1.meeting.endDate }
            .first

        guard let candidate else { return }

        promptedMeetingKeys.insert(promptKey(meeting: candidate.meeting, contact: candidate.contact))
        afterMeetingPrompt = candidate
    }

    private func promptKey(meeting: MeetingEvent, contact: Contact) -> String {
        "\(meeting.id)|\(meeting.startDate.timeIntervalSince1970)|\(contact.id.uuidString)"
    }

    private func contactForInteraction(_ interaction: Interaction) -> Contact? {
        contactsViewModel.repository.contacts.first { $0.id == interaction.contactId }
    }

    private func markFollowUpDone(_ interaction: Interaction) {
        var updated = interaction
        updated.followUpDate = nil
        interactionRepository.update(updated)
    }

    private func relationshipStatus(for contact: Contact) -> (status: String, daysSince: Int?) {
        interactionRepository.getRelationshipStatus(for: contact.id)
    }

    private func colorForRelationshipStatus(_ status: String) -> Color {
        switch status {
        case "Strong":
            return .green
        case "Medium":
            return .orange
        case "Weak":
            return .red
        default:
            return .secondary
        }
    }

    private func createContactFromMeeting(_ meeting: MeetingEvent) {
        let extracted = extractContactDraft(from: meeting)
        let fullName = [extracted.firstName, extracted.lastName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        if contactsViewModel.repository.findByEmailOrFullName(
            email: extracted.email,
            fullName: fullName
        ) != nil {
            showingContactExistsAlert = true
            return
        }

        let newContact = Contact(
            firstName: extracted.firstName,
            lastName: extracted.lastName,
            email: extracted.email,
            notes: "",
            tags: [],
            createdAt: Date()
        )

        contactsViewModel.addContact(newContact)
        createdContactForEditing = newContact
    }

    private func extractContactDraft(from meeting: MeetingEvent) -> (firstName: String, lastName: String, email: String) {
        if let attendeeEmail = meeting.attendeeEmails.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            let nameSource = attendeeName(from: attendeeEmail)
            let split = splitName(nameSource)
            return (split.firstName, split.lastName, attendeeEmail)
        }

        let split = splitName(meeting.title)
        return (split.firstName, split.lastName, "")
    }

    private func attendeeName(from email: String) -> String {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let localPart = normalized.split(separator: "@").first else {
            return normalized
        }

        let cleaned = localPart
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else { return normalized }
        return cleaned
            .split(whereSeparator: \.isWhitespace)
            .map { token in
                token.prefix(1).uppercased() + token.dropFirst().lowercased()
            }
            .joined(separator: " ")
    }

    private func splitName(_ raw: String) -> (firstName: String, lastName: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)

        if parts.count >= 2 {
            return (parts[0], parts.dropFirst().joined(separator: " "))
        }

        if let only = parts.first, !only.isEmpty {
            return (only, "")
        }

        return ("Unknown", "")
    }

    private func notesPreview(_ notes: String) -> String {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "No notes" }
        if trimmed.count <= 90 {
            return trimmed
        }
        let index = trimmed.index(trimmed.startIndex, offsetBy: 90)
        return "\(trimmed[..<index])..."
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
