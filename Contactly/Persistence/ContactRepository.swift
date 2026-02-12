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

    static var preview: ContactRepository {
        let repo = ContactRepository()
        repo.contacts = Contact.previewList
        return repo
    }
}
