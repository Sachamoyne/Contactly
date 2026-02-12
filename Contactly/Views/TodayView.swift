import SwiftUI

struct TodayView: View {
    var meetingService: MeetingService
    var contactsViewModel: ContactsViewModel
    var notificationService: NotificationService
    var settingsRepository: SettingsRepository

    @StateObject private var viewModel: TodayViewModel
    @State private var showingErrorAlert = false
    @State private var showingManualMeetingSheet = false
    @State private var editingManualMeeting: ManualMeeting?

    init(
        meetingService: MeetingService,
        contactsViewModel: ContactsViewModel,
        notificationService: NotificationService,
        settingsRepository: SettingsRepository
    ) {
        self.meetingService = meetingService
        self.contactsViewModel = contactsViewModel
        self.notificationService = notificationService
        self.settingsRepository = settingsRepository
        _viewModel = StateObject(wrappedValue: TodayViewModel(meetingService: meetingService))
    }

    var body: some View {
        List {
            Section("Today's Meetings") {
                if viewModel.meetingEvents.isEmpty {
                    Text("No synced meetings with attendees today.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.meetingEvents) { meeting in
                        syncedMeetingRow(meeting)
                    }
                }
            }

            Section("Manual Meetings") {
                if viewModel.manualMeetings.isEmpty {
                    Text("No manual meetings created.")
                        .foregroundStyle(.secondary)
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
                                .tint(.blue)
                            }
                    }
                }
            }
        }
        .overlay {
            if viewModel.isLoading {
                ZStack {
                    Color.black.opacity(0.1)
                        .ignoresSafeArea()
                    ProgressView("Syncing meetings...")
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
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
                }
                .disabled(contactsViewModel.repository.contacts.isEmpty)
            }
        }
        .navigationDestination(for: Contact.self) { contact in
            ContactView(contact: contact, viewModel: contactsViewModel)
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
        .alert("Meeting Sync", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .task {
            await refresh()
        }
        .refreshable {
            await refresh()
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            showingErrorAlert = newValue != nil
        }
    }

    private func syncedMeetingRow(_ meeting: MeetingEvent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(meeting.linkedContact?.fullName.isEmpty == false ? (meeting.linkedContact?.fullName ?? "") : (meeting.attendeeEmails.first ?? "Unknown attendee"))
                    .font(.headline)
                Spacer()
                Text("\(meeting.startDate.formatted(date: .omitted, time: .shortened)) - \(meeting.endDate.formatted(date: .omitted, time: .shortened))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(meeting.title)
                .font(.subheadline.weight(.semibold))

            Text(notesSummary(for: meeting.linkedContact))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let contact = meeting.linkedContact {
                NavigationLink(value: contact) {
                    Text("Review Contact")
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func manualMeetingRow(_ meeting: ManualMeeting) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(viewModel.contact(for: meeting)?.fullName ?? "Unknown contact")
                    .font(.headline)
                Spacer()
                Text(meeting.date, style: .time)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(meeting.occasion)
                .font(.subheadline.weight(.semibold))

            if !meeting.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(meeting.notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
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
}
