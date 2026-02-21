import Contacts
import SwiftUI
import UIKit

struct ContactsImportView: View {
    let repository: ContactRepository

    @State private var importService = ContactImportService()
    @State private var isImportDialogPresented = false
    @State private var isPickerPresented = false
    @State private var isImporting = false
    @State private var showPermissionDeniedAlert = false
    @State private var showToast = false
    @State private var toastMessage = ""

    var body: some View {
        Form {
            Section("Contacts") {
                Button("Import from iPhone Contacts") {
                    isImportDialogPresented = true
                }
            }
        }
        .navigationTitle("Import Contacts")
        .confirmationDialog("Import Contacts", isPresented: $isImportDialogPresented) {
            Button("Select Contacts") {
                Task {
                    await prepareContactPicker()
                }
            }

            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $isPickerPresented) {
            ContactPickerSheet(
                onSelect: { contacts in
                    Task {
                        await importSelectedContacts(contacts)
                    }
                },
                onCancel: {}
            )
        }
        .alert("Contacts Access Disabled", isPresented: $showPermissionDeniedAlert) {
            Button("Open Settings") {
                openAppSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable Contacts access in Settings to use this feature.")
        }
        .overlay {
            if isImporting {
                ZStack {
                    Color.black.opacity(0.15)
                        .ignoresSafeArea()
                    ProgressView("Importing contacts...")
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
    }

    private func prepareContactPicker() async {
        let hasAccess = await importService.requestAccess()
        guard hasAccess else {
            showPermissionDeniedAlert = true
            return
        }
        isPickerPresented = true
    }

    private func importSelectedContacts(_ contacts: [CNContact]) async {
        isPickerPresented = false
        isImporting = true

        let mappedContacts = importService.mapContacts(contacts)
        let importedCount = saveUniqueContacts(mappedContacts)

        isImporting = false
        showImportToast(count: importedCount)
    }

    private func saveUniqueContacts(_ contacts: [Contact]) -> Int {
        var existingEmails = Set(
            repository.contacts.compactMap { normalizedEmail($0.email) }
        )
        var existingPhones = Set(
            repository.contacts.compactMap { normalizedPhone($0.phone) }
        )
        var imported = 0

        for contact in contacts {
            let email = normalizedEmail(contact.email)
            let phone = normalizedPhone(contact.phone)
            let isDuplicateByEmail = email.map { existingEmails.contains($0) } ?? false
            let isDuplicateByPhone = phone.map { existingPhones.contains($0) } ?? false

            if isDuplicateByEmail || isDuplicateByPhone {
                continue
            }
            repository.add(contact)
            if let email {
                existingEmails.insert(email)
            }
            if let phone {
                existingPhones.insert(phone)
            }
            imported += 1
        }

        return imported
    }

    private func normalizedEmail(_ email: String) -> String? {
        let value = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return value.isEmpty ? nil : value
    }

    private func normalizedPhone(_ phone: String) -> String? {
        let value = phone.filter { $0.isWholeNumber }
        return value.isEmpty ? nil : value
    }

    private func showImportToast(count: Int) {
        toastMessage = "\(count) contacts imported"
        showToast = true

        Task {
            try? await Task.sleep(for: .seconds(2))
            showToast = false
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
