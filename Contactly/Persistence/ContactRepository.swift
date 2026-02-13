import Foundation
import Observation

@Observable
final class ContactRepository {
    private static let filename = "contacts.json"

    private(set) var contacts: [Contact] = []

    init() {
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
    }

    func update(_ contact: Contact) {
        guard let index = contacts.firstIndex(where: { $0.id == contact.id }) else { return }
        contacts[index] = contact
        save()
    }

    func delete(_ contact: Contact) {
        contacts.removeAll { $0.id == contact.id }
        save()
    }

    func clear() {
        contacts.removeAll()
        save()
    }

    func delete(at offsets: IndexSet, in sortedContacts: [Contact]) {
        let idsToDelete = offsets.map { sortedContacts[$0].id }
        contacts.removeAll { idsToDelete.contains($0.id) }
        save()
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

    static var preview: ContactRepository {
        let repo = ContactRepository()
        repo.contacts = Contact.previewList
        return repo
    }
}
