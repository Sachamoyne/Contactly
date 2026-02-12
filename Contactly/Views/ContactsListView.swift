import Contacts
import SwiftUI
import UIKit

struct ContactsListView: View {
    @Bindable var viewModel: ContactsViewModel

    @State private var importService = ContactImportService()
    @State private var showingAddContact = false
    @State private var showingImportDialog = false
    @State private var showingContactPicker = false
    @State private var isImporting = false
    @State private var showPermissionDeniedAlert = false
    @State private var showToast = false
    @State private var toastMessage = ""

    var body: some View {
        Group {
            if viewModel.filteredContacts.isEmpty {
                ContentUnavailableView(
                    viewModel.searchText.isEmpty ? "No Contacts" : "No Results",
                    systemImage: viewModel.searchText.isEmpty
                        ? "person.crop.circle"
                        : "magnifyingglass",
                    description: Text(
                        viewModel.searchText.isEmpty
                            ? "Tap + to add your first contact."
                            : "No contacts match your search."
                    )
                )
            } else {
                List {
                    ForEach(viewModel.filteredContacts) { contact in
                        NavigationLink(value: contact) {
                            ContactRowView(contact: contact)
                        }
                    }
                    .onDelete { offsets in
                        viewModel.deleteContacts(at: offsets)
                    }
                }
            }
        }
        .navigationTitle("Contacts")
        .searchable(text: $viewModel.searchText, prompt: "Search contacts")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Import") {
                    showingImportDialog = true
                }

                Button {
                    showingAddContact = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .navigationDestination(for: Contact.self) { contact in
            ContactView(contact: contact, viewModel: viewModel)
        }
        .sheet(isPresented: $showingAddContact) {
            EditContactView(viewModel: viewModel)
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
        .confirmationDialog("Import Contacts", isPresented: $showingImportDialog) {
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
        .alert("Contacts Access Needed", isPresented: $showPermissionDeniedAlert) {
            Button("Open Settings") {
                openAppSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please allow Contacts access in Settings to import your iPhone contacts.")
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
            await MainActor.run {
                showPermissionDeniedAlert = true
            }
            return
        }

        await MainActor.run {
            showingContactPicker = true
        }
    }

    private func importAllContacts() async {
        guard await importService.requestAccess() else {
            await MainActor.run {
                showPermissionDeniedAlert = true
            }
            return
        }

        await MainActor.run {
            isImporting = true
        }

        let fetchedContacts = await importService.fetchAllContacts()

        await MainActor.run {
            let importedCount = saveUniqueContacts(fetchedContacts)
            isImporting = false
            showImportToast(count: importedCount)
        }
    }

    private func importSelectedContacts(_ contacts: [CNContact]) async {
        await MainActor.run {
            showingContactPicker = false
            isImporting = true
        }

        let mappedContacts = importService.mapContacts(contacts)

        await MainActor.run {
            let importedCount = saveUniqueContacts(mappedContacts)
            isImporting = false
            showImportToast(count: importedCount)
        }
    }

    private func saveUniqueContacts(_ contacts: [Contact]) -> Int {
        let existingKeys = Set(
            viewModel.repository.contacts.map { contact in
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
            viewModel.addContact(contact)
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
            await MainActor.run {
                showToast = false
            }
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

private struct ContactRowView: View {
    let contact: Contact

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(contact: contact, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(contact.fullName.isEmpty ? "No Name" : contact.fullName)
                    .font(.body)
                    .fontWeight(.medium)

                if !contact.company.isEmpty {
                    Text(contact.company)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
