import Contacts
import Foundation
import Observation

@MainActor
@Observable
final class OnboardingViewModel {
    enum Step: Int, CaseIterable {
        case intro
        case userInfo
        case calendarSelection
        case contactSync
        case completion

        var title: String {
            switch self {
            case .intro:
                return "Welcome"
            case .userInfo:
                return "Your Details"
            case .calendarSelection:
                return "Calendar Sync"
            case .contactSync:
                return "Contact Sync"
            case .completion:
                return "Complete"
            }
        }

        var progressText: String {
            switch self {
            case .intro:
                return "Welcome"
            case .userInfo:
                return "Step 1 of 3"
            case .calendarSelection:
                return "Step 2 of 3"
            case .contactSync:
                return "Step 3 of 3"
            case .completion:
                return "All Set"
            }
        }
    }

    let userProfileStore: UserProfileStore
    let settingsRepository: SettingsRepository
    let calendarService: CalendarService
    let googleCalendarService: GoogleCalendarService
    let contactImportService: ContactImportService
    let contactRepository: ContactRepository

    var currentStep: Step = .intro
    var firstName: String
    var lastName: String
    var email: String
    var selectedCalendarProvider: CalendarProvider
    var selectedContactSyncOption: ContactSyncOption
    var isProcessing = false
    var errorMessage: String?

    init(
        userProfileStore: UserProfileStore,
        settingsRepository: SettingsRepository,
        calendarService: CalendarService,
        googleCalendarService: GoogleCalendarService,
        contactImportService: ContactImportService,
        contactRepository: ContactRepository
    ) {
        self.userProfileStore = userProfileStore
        self.settingsRepository = settingsRepository
        self.calendarService = calendarService
        self.googleCalendarService = googleCalendarService
        self.contactImportService = contactImportService
        self.contactRepository = contactRepository

        firstName = userProfileStore.profile.firstName
        lastName = userProfileStore.profile.lastName
        email = userProfileStore.profile.email
        selectedCalendarProvider = userProfileStore.profile.calendarProvider
        selectedContactSyncOption = userProfileStore.profile.contactSyncOption
    }

    var canContinueUserInfo: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && isValidEmail(email)
    }

    func continueFromIntro() {
        currentStep = .userInfo
    }

    func continueFromUserInfo() {
        guard canContinueUserInfo else {
            errorMessage = "Please provide a valid name and email."
            return
        }

        persistProfile()
        currentStep = .calendarSelection
    }

    func continueFromCalendarSelection() async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            switch selectedCalendarProvider {
            case .apple:
                let granted = await calendarService.requestFullAccessToEvents()
                guard granted else {
                    throw OnboardingError.calendarPermissionDenied
                }
            case .google:
                try await googleCalendarService.signIn()
                _ = try await googleCalendarService.fetchUpcomingEvents(daysAhead: 1)
            case .none:
                break
            }

            settingsRepository.setCalendarProviders(selectedCalendarProvider == .none ? [] : [selectedCalendarProvider])
            persistProfile()
            currentStep = .contactSync
        } catch {
            errorMessage = readableError(from: error)
        }
    }

    func importAllContactsAndContinue() async {
        isProcessing = true
        defer { isProcessing = false }

        guard await contactImportService.requestAccess() else {
            errorMessage = "Contacts access is required to import all contacts."
            return
        }

        let importedContacts: [Contact]
        do {
            let rawContacts = try await contactImportService.fetchAllContactsAsync()
            importedContacts = contactImportService.mapContacts(rawContacts)
        } catch {
            errorMessage = "Unable to import all contacts right now."
            return
        }
        saveUniqueContacts(importedContacts)
        print("[ContactImport] Imported \(importedContacts.count) contacts during onboarding (all).")
        selectedContactSyncOption = .all
        persistProfile()
        currentStep = .completion
    }

    func importSelectedContactsAndContinue(_ selectedContacts: [CNContact]) {
        let contacts = contactImportService.mapContacts(selectedContacts)
        saveUniqueContacts(contacts)
        selectedContactSyncOption = .selected
        persistProfile()
        currentStep = .completion
    }

    func skipContactSyncAndContinue() {
        selectedContactSyncOption = .none
        persistProfile()
        currentStep = .completion
    }

    func finishOnboarding() {
        persistProfile()
        userProfileStore.completeOnboarding()
    }

    private func persistProfile() {
        let profile = UserProfile(
            firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
            lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            calendarProvider: selectedCalendarProvider,
            contactSyncOption: selectedContactSyncOption
        )
        userProfileStore.updateProfile(profile)
    }

    private func saveUniqueContacts(_ contacts: [Contact]) {
        var seenEmails = Set(
            contactRepository.contacts.compactMap { normalizedEmail($0.email) }
        )
        var seenPhones = Set(
            contactRepository.contacts.compactMap { normalizedPhone($0.phone) }
        )

        for contact in contacts {
            let email = normalizedEmail(contact.email)
            let phone = normalizedPhone(contact.phone)
            let isDuplicateByEmail = email.map { seenEmails.contains($0) } ?? false
            let isDuplicateByPhone = phone.map { seenPhones.contains($0) } ?? false

            if isDuplicateByEmail || isDuplicateByPhone {
                continue
            }
            contactRepository.add(contact)
            if let email {
                seenEmails.insert(email)
            }
            if let phone {
                seenPhones.insert(phone)
            }
        }
    }

    private func normalizedEmail(_ email: String) -> String? {
        let value = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return value.isEmpty ? nil : value
    }

    private func normalizedPhone(_ phone: String) -> String? {
        let value = phone.filter { $0.isWholeNumber }
        return value.isEmpty ? nil : value
    }

    private func isValidEmail(_ email: String) -> Bool {
        let value = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let regex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: value)
    }

    private func readableError(from error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? "An unexpected error occurred."
    }
}

enum OnboardingError: LocalizedError {
    case calendarPermissionDenied

    var errorDescription: String? {
        switch self {
        case .calendarPermissionDenied:
            return "Calendar access was denied. You can choose another option or enable access in Settings."
        }
    }
}
