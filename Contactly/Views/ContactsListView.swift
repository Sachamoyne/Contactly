import Contacts
import SwiftUI
import UIKit

struct ContactsListView: View {
    @Bindable var viewModel: ContactsViewModel
    var interactionRepository: InteractionRepository

    @State private var importService = ContactImportService()
    @State private var showingAddContact = false
    @State private var showingImportDialog = false
    @State private var showingContactPicker = false
    @State private var isImporting = false
    @State private var showPermissionDeniedAlert = false
    @State private var showToast = false
    @State private var toastMessage = ""

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
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
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                        .onDelete { offsets in
                            viewModel.deleteContacts(at: offsets)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.plain)
                }
            }

            Button {
                showingAddContact = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(Circle().fill(AppTheme.accent))
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            }
            .padding(.trailing, AppTheme.spacingMedium)
            .padding(.bottom, AppTheme.spacingLarge)
            .accessibilityLabel("Add Contact")
        }
        .background(Color(uiColor: .systemBackground))
        .navigationTitle("Contacts")
        .searchable(text: $viewModel.searchText, prompt: "Search contacts")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Import") {
                    showingImportDialog = true
                }
                .foregroundStyle(AppTheme.accent)
            }
        }
        .navigationDestination(for: Contact.self) { contact in
            ContactView(
                contact: contact,
                viewModel: viewModel,
                interactionRepository: interactionRepository
            )
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
                        .padding(AppTheme.spacingMedium)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
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

    private var subtitle: String {
        let trimmedNotes = contact.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNotes.isEmpty {
            return trimmedNotes
        }

        if !contact.tags.isEmpty {
            return contact.tags.joined(separator: " • ")
        }

        if !contact.company.isEmpty {
            return contact.company
        }

        return "No additional details"
    }

    var body: some View {
        HStack(spacing: AppTheme.spacingMedium) {
            AvatarView(contact: contact, size: 52)

            VStack(alignment: .leading, spacing: 6) {
                Text(contact.fullName.isEmpty ? "No Name" : contact.fullName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(AppTheme.spacingMedium)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }
}
