import Foundation

@Observable
final class ContactRepository {
    private(set) var contacts: [Contact] = []

    private let fileURL: URL

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.fileURL = documents.appendingPathComponent("contacts.json")
        load()
    }

    // MARK: - CRUD

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

    // MARK: - Sorting

    func sortedByName() -> [Contact] {
        contacts.sorted {
            $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending
        }
    }

    // MARK: - Persistence

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(contacts)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save contacts: \(error)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            contacts = try decoder.decode([Contact].self, from: data)
        } catch {
            print("Failed to load contacts: \(error)")
        }
    }
}
