import Foundation
import Observation

@Observable
final class ContactRepository {
    private static let filename = "contacts.json"
    private let notificationService: NotificationService

    private(set) var contacts: [Contact] = []

    init(notificationService: NotificationService = .shared) {
        self.notificationService = notificationService
        load()
    }

    func load() {
        guard PersistenceStore.exists(Self.filename) else { return }
        do {
            contacts = try PersistenceStore.load([Contact].self, from: Self.filename)
        } catch {
            contacts = []
        }
    }

    func save() {
        try? PersistenceStore.save(contacts, to: Self.filename)
    }

    func add(_ contact: Contact) {
        contacts.append(contact)
        save()
        notificationService.scheduleBirthdayNotification(for: contact)
    }

    func update(_ contact: Contact) {
        guard let index = contacts.firstIndex(where: { $0.id == contact.id }) else { return }
        contacts[index] = contact
        save()
        notificationService.scheduleBirthdayNotification(for: contact)
    }

    func delete(_ contact: Contact) {
        contacts.removeAll { $0.id == contact.id }
        save()
        notificationService.removeBirthdayNotification(for: contact.id)
    }

    func clear() {
        let deletedIDs = contacts.map(\.id)
        contacts.removeAll()
        save()
        deletedIDs.forEach { notificationService.removeBirthdayNotification(for: $0) }
    }

    func delete(at offsets: IndexSet, in sortedContacts: [Contact]) {
        let idsToDelete = offsets.map { sortedContacts[$0].id }
        contacts.removeAll { idsToDelete.contains($0.id) }
        save()
        idsToDelete.forEach { notificationService.removeBirthdayNotification(for: $0) }
    }

    func sortedByName() -> [Contact] {
        contacts.sorted {
            $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending
        }
    }

    func findByEmailOrFullName(email: String, fullName: String) -> Contact? {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedFullName = fullName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return contacts.first { contact in
            let contactEmail = contact.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let contactFullName = contact.fullName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            let emailMatches = !normalizedEmail.isEmpty && !contactEmail.isEmpty && contactEmail == normalizedEmail
            let fullNameMatches = !normalizedFullName.isEmpty && !contactFullName.isEmpty && contactFullName == normalizedFullName
            return emailMatches || fullNameMatches
        }
    }

    // Compatibility helpers for interaction CRUD without changing persistence structure.
    func updateInteraction(
        contactID: UUID,
        interaction: Interaction,
        using interactionRepository: InteractionRepository? = nil
    ) {
        guard interaction.contactId == contactID else { return }
        let repository = interactionRepository ?? InteractionRepository()
        if interactionRepository == nil {
            repository.load()
        }
        repository.update(interaction)
        refreshLastInteractionDate(for: contactID, using: repository)
    }

    func deleteInteraction(
        contactID: UUID,
        interactionID: UUID,
        using interactionRepository: InteractionRepository? = nil
    ) {
        let repository = interactionRepository ?? InteractionRepository()
        if interactionRepository == nil {
            repository.load()
        }
        guard let interaction = repository.interactions.first(where: { $0.id == interactionID && $0.contactId == contactID }) else {
            return
        }
        repository.delete(interaction)
        refreshLastInteractionDate(for: contactID, using: repository)
    }

    private func refreshLastInteractionDate(for contactID: UUID, using repository: InteractionRepository) {
        guard let index = contacts.firstIndex(where: { $0.id == contactID }) else { return }
        let latestDate = repository
            .getInteractions(for: contactID)
            .map(\.date)
            .max()
        contacts[index].lastInteractionDate = latestDate
        save()
    }

    static var preview: ContactRepository {
        let repo = ContactRepository()
        repo.contacts = Contact.previewList
        return repo
    }
}
