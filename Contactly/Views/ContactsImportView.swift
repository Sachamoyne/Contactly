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
    @State private var showImportErrorAlert = false
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
            Button("Import All Contacts") {
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
        .alert("Contacts Access Needed", isPresented: $showPermissionDeniedAlert) {
            Button("Open Settings") {
                openAppSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please allow Contacts access in Settings to import your iPhone contacts.")
        }
        .alert("Import Failed", isPresented: $showImportErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Unable to import contacts right now. Please try again.")
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

    private func importAllContacts() async {
        guard await importService.requestAccess() else {
            showPermissionDeniedAlert = true
            return
        }

        isImporting = true
        let fetchedContacts = await importService.fetchAllContacts()
        let importedCount = saveUniqueContacts(fetchedContacts)
        isImporting = false

        showImportToast(count: importedCount)
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
        let existingKeys = Set(
            repository.contacts.map { contact in
                duplicateKey(name: contact.fullName, email: contact.email)
            }
        )

        var newKeys = existingKeys
        var imported = 0

        for contact in contacts {
            let key = duplicateKey(name: contact.fullName, email: contact.email)
            if newKeys.contains(key) {
                continue
            }
            repository.add(contact)
            newKeys.insert(key)
            imported += 1
        }

        return imported
    }

    private func duplicateKey(name: String, email: String) -> String {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(normalizedName)|\(normalizedEmail)"
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
