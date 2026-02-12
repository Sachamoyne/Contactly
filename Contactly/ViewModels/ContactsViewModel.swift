import Foundation
import Observation

@Observable
final class ContactsViewModel {
    let repository: ContactRepository
    var searchText: String = ""

    var filteredContacts: [Contact] {
        let sorted = repository.sortedByName()
        if searchText.isEmpty { return sorted }
        return sorted.filter { contact in
            contact.fullName.localizedCaseInsensitiveContains(searchText)
                || contact.company.localizedCaseInsensitiveContains(searchText)
                || contact.email.localizedCaseInsensitiveContains(searchText)
                || contact.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    init(repository: ContactRepository) {
        self.repository = repository
    }

    func addContact(_ contact: Contact) {
        repository.add(contact)
    }

    func updateContact(_ contact: Contact) {
        repository.update(contact)
    }

    func deleteContact(_ contact: Contact) {
        repository.delete(contact)
    }

    func deleteContacts(at offsets: IndexSet) {
        repository.delete(at: offsets, in: filteredContacts)
    }

    func clearAllContacts() {
        repository.clear()
    }
}
