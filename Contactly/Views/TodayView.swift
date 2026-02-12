import SwiftUI

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

    private var nextMeeting: MeetingEvent? {
        viewModel.meetingEvents.first
    }

    private var upcomingMeetings: [MeetingEvent] {
        Array(viewModel.meetingEvents.dropFirst())
    }

    private var pendingFollowUps: [PendingFollowUpItem] {
        interactionRepository.getPendingFollowUps().compactMap { interaction in
            guard let contact = contactForInteraction(interaction) else { return nil }
            return PendingFollowUpItem(interaction: interaction, contact: contact)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.spacingLarge) {
                followUpsSection
                todaysMeetingsSection
                manualMeetingsSection
            }
            .padding(.horizontal, AppTheme.spacingMedium)
            .padding(.vertical, AppTheme.spacingMedium)
        }
        .background(Color(uiColor: .systemBackground))
        .overlay {
            if viewModel.isLoading {
                ZStack {
                    Color.black.opacity(0.1).ignoresSafeArea()
                    ProgressView("Syncing meetings...")
                        .padding(AppTheme.spacingMedium)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                }
            }
        }
        .navigationTitle("Today")
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
        .alert("Meeting Sync", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
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

    @ViewBuilder
    private var followUpsSection: some View {
        if !pendingFollowUps.isEmpty {
            VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
                Text("Follow Ups")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                ForEach(pendingFollowUps) { item in
                    followUpRow(item)
                }
            }
        }
    }

    private var todaysMeetingsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
            Text("Today's Meetings")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            if let meeting = nextMeeting {
                nextMeetingCard(meeting)
            } else {
                Text("No synced meetings with attendees today.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppTheme.spacingMedium)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                            .fill(Color(uiColor: .secondarySystemBackground))
                    )
            }

            if !upcomingMeetings.isEmpty {
                VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                    Text("Upcoming")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    ForEach(upcomingMeetings) { meeting in
                        syncedMeetingRow(meeting)
                    }
                }
            }
        }
    }

    private var manualMeetingsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
            Text("Manual Meetings")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            if viewModel.manualMeetings.isEmpty {
                Text("No manual meetings created.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppTheme.spacingMedium)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                            .fill(Color(uiColor: .secondarySystemBackground))
                    )
            } else {
                ForEach(viewModel.manualMeetings) { manualMeeting in
                    manualMeetingRow(manualMeeting)
                        .swipeActions(edge: .trailing) {
                            Button("Delete", role: .destructive) {
                                Task {
                                    await viewModel.deleteManualMeeting(manualMeeting)
                                }
                            }

                            Button("Edit") {
                                editingManualMeeting = manualMeeting
                            }
                            .tint(AppTheme.accent)
                        }
                }
            }
        }
    }

    private func nextMeetingCard(_ meeting: MeetingEvent) -> some View {
        let matchedContact = contactForMeeting(meeting)

        return VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
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

                VStack(alignment: .leading, spacing: 6) {
                    Text(matchedContact?.fullName.isEmpty == false ? (matchedContact?.fullName ?? "") : (meeting.attendeeEmails.first ?? "Unknown attendee"))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)

                    Text("\(meeting.startDate.formatted(date: .omitted, time: .shortened)) - \(meeting.endDate.formatted(date: .omitted, time: .shortened))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(meeting.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
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
                }
            }
        }
        .padding(AppTheme.spacingLarge)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.heroCornerRadius, style: .continuous)
                .fill(AppTheme.tintBackground)
        )
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }

    private func syncedMeetingRow(_ meeting: MeetingEvent) -> some View {
        let matchedContact = contactForMeeting(meeting)

        return VStack(alignment: .leading, spacing: 8) {
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
                    Text(matchedContact?.fullName.isEmpty == false ? (matchedContact?.fullName ?? "") : (meeting.attendeeEmails.first ?? "Unknown attendee"))
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(meeting.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
            }
        }
        .padding(AppTheme.spacingMedium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private func manualMeetingRow(_ meeting: ManualMeeting) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(viewModel.contact(for: meeting)?.fullName ?? "Unknown contact")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text(meeting.date, style: .time)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(meeting.occasion)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            if !meeting.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(meeting.notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(AppTheme.spacingMedium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private func followUpRow(_ item: PendingFollowUpItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: AppTheme.spacingSmall) {
                AvatarView(contact: item.contact, size: 42)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.contact.fullName.isEmpty ? "Unknown Contact" : item.contact.fullName)
                        .font(.headline)
                        .foregroundStyle(.primary)

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

                Button("Mark Done") {
                    markFollowUpDone(item.interaction)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(AppTheme.chipBackground))
            }
        }
        .padding(AppTheme.spacingMedium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
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
            return "No contact linked yet."
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
        if !notificationService.isAuthorized {
            _ = await notificationService.requestAuthorization()
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

    private func notesPreview(_ notes: String) -> String {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "No notes" }
        if trimmed.count <= 90 {
            return trimmed
        }
        let index = trimmed.index(trimmed.startIndex, offsetBy: 90)
        return "\(trimmed[..<index])..."
    }
}
