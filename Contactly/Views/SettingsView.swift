import Contacts
import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @Bindable var repository: SettingsRepository
    @Bindable var contactsViewModel: ContactsViewModel
    @Bindable var userProfileStore: UserProfileStore
    @Bindable var googleCalendarService: GoogleCalendarService
    @Bindable var notificationService: NotificationService
    var appleCalendarService: CalendarService
    var calendarAggregatorService: CalendarAggregatorService

    @Environment(\.scenePhase) private var scenePhase
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
            Section("Calendar") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Connected calendar")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(userProfileStore.profile.calendarProvider.displayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                }

                Button("Choose Calendar Provider") {
                    showingCalendarSelection = true
                }
                .buttonStyle(PressScaleButtonStyle())

                if userProfileStore.profile.calendarProvider == .google {
                    Button("Disconnect Google Calendar") {
                        disconnectGoogle()
                    }
                    .foregroundStyle(.red.opacity(0.7))
                    .buttonStyle(PressScaleButtonStyle())
                }

            }

            Section("Notifications") {
                if notificationService.authorizationStatus == .denied {
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.secondary)
                        Text("Notifications are disabled")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Open Settings") {
                            openAppSettings()
                        }
                        .buttonStyle(PressScaleButtonStyle())
                    }
                }

                Picker("Meeting reminder", selection: $repository.settings.delayMinutes) {
                    Text("5 minutes before").tag(5)
                    Text("10 minutes before").tag(10)
                    Text("15 minutes before").tag(15)
                    Text("30 minutes before").tag(30)
                    Text("1 hour before").tag(60)
                }
                Toggle("Quiet hours", isOn: $repository.settings.quietHours.isEnabled)
                    .tint(AppTheme.accent)

                if repository.settings.quietHours.isEnabled {
                    DatePicker(
                        "Quiet hours start",
                        selection: quietHoursStartBinding,
                        displayedComponents: .hourAndMinute
                    )
                    DatePicker(
                        "Quiet hours end",
                        selection: quietHoursEndBinding,
                        displayedComponents: .hourAndMinute
                    )
                }
            }

            Section("Preferences") {
                Button("Import Contacts") {
                    showingContactImportDialog = true
                }
                .buttonStyle(PressScaleButtonStyle())

                Button("Clear Imported Contacts") {
                    showingClearContactsConfirmation = true
                }
                .foregroundStyle(.red.opacity(0.7))
                .buttonStyle(PressScaleButtonStyle())
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog("Choose Calendar", isPresented: $showingCalendarSelection) {
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

            Button("No Calendar Sync") {
                selectCalendarProviderNone()
            }

            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Import Contacts", isPresented: $showingContactImportDialog) {
            Button("Choose Contacts") {
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
        .alert("Contacts Access Disabled", isPresented: $showingPermissionDeniedAlert) {
            Button("Open Settings") {
                openAppSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable Contacts access in Settings to use this feature.")
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
                    ProgressView("Updating...")
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
        .task {
            await notificationService.checkAuthorizationStatus()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await notificationService.checkAuthorizationStatus()
            }
        }
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

    private func disconnectGoogle() {
        googleCalendarService.signOut()
        if userProfileStore.profile.calendarProvider == .google {
            updateProfileCalendarProvider(.none)
            repository.setCalendarProviders([])
        }
        showToastMessage("Google disconnected")
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
        var seenEmails = Set(
            contactsViewModel.repository.contacts.compactMap { normalizedEmail($0.email) }
        )
        var seenPhones = Set(
            contactsViewModel.repository.contacts.compactMap { normalizedPhone($0.phone) }
        )
        var importedCount = 0

        for contact in contacts {
            let email = normalizedEmail(contact.email)
            let phone = normalizedPhone(contact.phone)
            let isDuplicateByEmail = email.map { seenEmails.contains($0) } ?? false
            let isDuplicateByPhone = phone.map { seenPhones.contains($0) } ?? false

            if isDuplicateByEmail || isDuplicateByPhone {
                continue
            }
            contactsViewModel.addContact(contact)
            if let email {
                seenEmails.insert(email)
            }
            if let phone {
                seenPhones.insert(phone)
            }
            importedCount += 1
        }

        return importedCount
    }

    private func normalizedEmail(_ email: String) -> String? {
        let value = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return value.isEmpty ? nil : value
    }

    private func normalizedPhone(_ phone: String) -> String? {
        let value = phone.filter { $0.isWholeNumber }
        return value.isEmpty ? nil : value
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
