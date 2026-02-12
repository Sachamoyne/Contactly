import Contacts
import Foundation

final class ContactImportService {
    private let store = CNContactStore()

    func requestAccess() async -> Bool {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        switch status {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                store.requestAccess(for: .contacts) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        case .limited:
            return true
        @unknown default:
            return false
        }
    }

    func fetchAllContacts() async -> [Contact] {
        let keys: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor
        ]

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = CNContactFetchRequest(keysToFetch: keys)
                var contacts: [Contact] = []

                do {
                    try self.store.enumerateContacts(with: request) { cnContact, _ in
                        contacts.append(self.mapToContact(cnContact))
                    }
                    continuation.resume(returning: contacts)
                } catch {
                    continuation.resume(returning: [])
                }
            }
        }
    }

    func mapContacts(_ contacts: [CNContact]) -> [Contact] {
        contacts.map(mapToContact)
    }

    private func mapToContact(_ cnContact: CNContact) -> Contact {
        let email = cnContact.emailAddresses.first?.value as String? ?? ""
        let phone = cnContact.phoneNumbers.first?.value.stringValue ?? ""

        let fallbackName = CNContactFormatter.string(from: cnContact, style: .fullName) ?? ""
        let firstName = cnContact.givenName.isEmpty ? fallbackName : cnContact.givenName

        return Contact(
            id: UUID(),
            firstName: firstName,
            lastName: cnContact.familyName,
            company: "",
            email: email,
            phone: phone,
            notes: "",
            tags: [],
            avatarPath: nil,
            createdAt: Date(),
            lastInteractionDate: nil
        )
    }
}
