import Contacts
import SwiftUI
import UIKit

struct SettingsView: View {
    @Bindable var repository: SettingsRepository
    @Bindable var contactsViewModel: ContactsViewModel
    @Bindable var userProfileStore: UserProfileStore
    @Bindable var googleCalendarService: GoogleCalendarService
    @Bindable var microsoftAuthService: MicrosoftAuthService
    var appleCalendarService: CalendarService
    var calendarAggregatorService: CalendarAggregatorService

    @State private var importService = ContactImportService()
    @State private var showingCalendarSelection = false
    @State private var showingContactImportDialog = false
    @State private var showingContactPicker = false
    @State private var showingPermissionDeniedAlert = false
    @State private var showingErrorAlert = false
    @State private var showingClearContactsConfirmation = false
    @State private var isWorking = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var errorMessage = ""

    var body: some View {
        Form {
            Section("Reminder Delay") {
                Picker("Notify me", selection: $repository.settings.delayMinutes) {
                    Text("5 minutes before").tag(5)
                    Text("10 minutes before").tag(10)
                    Text("15 minutes before").tag(15)
                    Text("30 minutes before").tag(30)
                    Text("1 hour before").tag(60)
                }
            }

            Section("Quiet Hours") {
                Toggle("Enable Quiet Hours", isOn: $repository.settings.quietHours.isEnabled)

                if repository.settings.quietHours.isEnabled {
                    DatePicker(
                        "Start",
                        selection: quietHoursStartBinding,
                        displayedComponents: .hourAndMinute
                    )
                    DatePicker(
                        "End",
                        selection: quietHoursEndBinding,
                        displayedComponents: .hourAndMinute
                    )
                }
            }

            Section("Calendar") {
                LabeledContent("Current Provider", value: userProfileStore.profile.calendarProvider.displayName)
                LabeledContent("Connected Providers", value: connectedProvidersLabel)

                Button("Change Provider") {
                    showingCalendarSelection = true
                }

                Button("Re-sync Calendar") {
                    Task {
                        await resyncCalendar()
                    }
                }

                if userProfileStore.profile.calendarProvider == .google {
                    Button("Re-authenticate Google") {
                        Task {
                            await reconnectGoogle()
                        }
                    }

                    Button("Disconnect Google", role: .destructive) {
                        disconnectGoogle()
                    }
                }

                if userProfileStore.profile.calendarProvider == .outlook {
                    Button("Re-authenticate Outlook") {
                        Task {
                            await reconnectOutlook()
                        }
                    }

                    Button("Disconnect Outlook", role: .destructive) {
                        Task {
                            await disconnectOutlook()
                        }
                    }
                }
            }

            Section("Contacts") {
                Button("Re-sync Contacts") {
                    showingContactImportDialog = true
                }

                Button("Clear Imported Contacts", role: .destructive) {
                    showingClearContactsConfirmation = true
                }
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog("Calendar Provider", isPresented: $showingCalendarSelection) {
            Button("Apple Calendar") {
                Task {
                    await selectCalendarProvider(.apple)
                }
            }

            Button("Google Calendar") {
                Task {
                    await selectCalendarProvider(.google)
                }
            }

            Button("Outlook Calendar") {
                Task {
                    await selectCalendarProvider(.outlook)
                }
            }

            Button("No Calendar Sync") {
                selectCalendarProviderNone()
            }

            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Contact Sync", isPresented: $showingContactImportDialog) {
            Button("Sync All Contacts") {
                Task {
                    await importAllContacts()
                }
            }

            Button("Select Contacts") {
                Task {
                    await prepareContactPicker()
                }
            }

            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Clear all imported contacts?", isPresented: $showingClearContactsConfirmation) {
            Button("Clear Contacts", role: .destructive) {
                contactsViewModel.clearAllContacts()
                showToastMessage("Contacts cleared")
            }

            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showingContactPicker) {
            ContactPickerSheet(
                onSelect: { contacts in
                    Task {
                        await importSelectedContacts(contacts)
                    }
                },
                onCancel: {}
            )
        }
        .alert("Permission Required", isPresented: $showingPermissionDeniedAlert) {
            Button("Open Settings") {
                openAppSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please allow access in iOS Settings to continue.")
        }
        .alert("Settings", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .overlay {
            if isWorking {
                ZStack {
                    Color.black.opacity(0.15)
                        .ignoresSafeArea()
                    ProgressView("Syncing...")
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .overlay(alignment: .bottom) {
            if showToast {
                Text(toastMessage)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showToast)
        .onChange(of: repository.settings) {
            repository.save()
        }
    }

    private var connectedProvidersLabel: String {
        var providers: [String] = []

        providers.append("Apple")

        if googleCalendarService.isSignedIn {
            providers.append("Google")
        }

        if microsoftAuthService.isSignedIn {
            providers.append("Outlook")
        }

        return providers.joined(separator: ", ")
    }

    private var quietHoursStartBinding: Binding<Date> {
        Binding(
            get: {
                dateFrom(hour: repository.settings.quietHours.startHour, minute: repository.settings.quietHours.startMinute)
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                repository.settings.quietHours.startHour = components.hour ?? 22
                repository.settings.quietHours.startMinute = components.minute ?? 0
            }
        )
    }

    private var quietHoursEndBinding: Binding<Date> {
        Binding(
            get: {
                dateFrom(hour: repository.settings.quietHours.endHour, minute: repository.settings.quietHours.endMinute)
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                repository.settings.quietHours.endHour = components.hour ?? 7
                repository.settings.quietHours.endMinute = components.minute ?? 0
            }
        )
    }

    private func selectCalendarProvider(_ provider: CalendarProvider) async {
        isWorking = true
        defer { isWorking = false }

        do {
            switch provider {
            case .apple:
                let granted = await appleCalendarService.requestFullAccessToEvents()
                guard granted else {
                    showingPermissionDeniedAlert = true
                    return
                }

            case .google:
                try await googleCalendarService.signIn()
                _ = try await googleCalendarService.fetchUpcomingEvents(daysAhead: 1)

            case .outlook:
                try await microsoftAuthService.signIn()

            case .none:
                break
            }

            updateProfileCalendarProvider(provider)
            repository.setCalendarProviders(provider == .none ? [] : [provider])
            showToastMessage("Calendar provider updated")
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to update calendar provider."
            showingErrorAlert = true
        }
    }

    private func selectCalendarProviderNone() {
        updateProfileCalendarProvider(.none)
        repository.setCalendarProviders([])
        showToastMessage("Calendar sync disabled")
    }

    private func reconnectGoogle() async {
        do {
            try await googleCalendarService.reconnect()
            showToastMessage("Google re-authenticated")
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to reconnect Google."
            showingErrorAlert = true
        }
    }

    private func reconnectOutlook() async {
        do {
            try await microsoftAuthService.signIn()
            showToastMessage("Outlook re-authenticated")
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to reconnect Outlook."
            showingErrorAlert = true
        }
    }

    private func disconnectGoogle() {
        googleCalendarService.signOut()
        if userProfileStore.profile.calendarProvider == .google {
            updateProfileCalendarProvider(.none)
            repository.setCalendarProviders([])
        }
        showToastMessage("Google disconnected")
    }

    private func disconnectOutlook() async {
        await microsoftAuthService.signOut()
        if userProfileStore.profile.calendarProvider == .outlook {
            updateProfileCalendarProvider(.none)
            repository.setCalendarProviders([])
        }
        showToastMessage("Outlook disconnected")
    }

    private func resyncCalendar() async {
        isWorking = true
        defer { isWorking = false }

        _ = await calendarAggregatorService.fetchTodayEvents()
        if let message = calendarAggregatorService.lastErrorMessage {
            errorMessage = message
            showingErrorAlert = true
            return
        }

        showToastMessage("Calendar re-synced")
    }

    private func prepareContactPicker() async {
        let hasAccess = await importService.requestAccess()
        guard hasAccess else {
            showingPermissionDeniedAlert = true
            return
        }

        showingContactPicker = true
    }

    private func importAllContacts() async {
        guard await importService.requestAccess() else {
            showingPermissionDeniedAlert = true
            return
        }

        isWorking = true
        let fetchedContacts = await importService.fetchAllContacts()
        let count = saveUniqueContacts(fetchedContacts)
        updateProfileContactSyncOption(.all)
        isWorking = false
        showToastMessage("\(count) contacts imported")
    }

    private func importSelectedContacts(_ contacts: [CNContact]) async {
        showingContactPicker = false
        isWorking = true

        let mapped = importService.mapContacts(contacts)
        let count = saveUniqueContacts(mapped)
        updateProfileContactSyncOption(.selected)

        isWorking = false
        showToastMessage("\(count) contacts imported")
    }

    private func saveUniqueContacts(_ contacts: [Contact]) -> Int {
        let existingKeys = Set(
            contactsViewModel.repository.contacts.map { contact in
                duplicateKey(name: contact.fullName, email: contact.email)
            }
        )

        var seen = existingKeys
        var importedCount = 0

        for contact in contacts {
            let key = duplicateKey(name: contact.fullName, email: contact.email)
            if seen.contains(key) {
                continue
            }
            contactsViewModel.addContact(contact)
            seen.insert(key)
            importedCount += 1
        }

        return importedCount
    }

    private func duplicateKey(name: String, email: String) -> String {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(normalizedName)|\(normalizedEmail)"
    }

    private func updateProfileCalendarProvider(_ provider: CalendarProvider) {
        var profile = userProfileStore.profile
        profile.calendarProvider = provider
        userProfileStore.updateProfile(profile)
    }

    private func updateProfileContactSyncOption(_ option: ContactSyncOption) {
        var profile = userProfileStore.profile
        profile.contactSyncOption = option
        userProfileStore.updateProfile(profile)
    }

    private func showToastMessage(_ message: String) {
        toastMessage = message
        showToast = true

        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                showToast = false
            }
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func dateFrom(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }
}
