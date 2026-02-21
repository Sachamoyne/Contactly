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
    @FocusState private var isSearchFocused: Bool
    private var hasAnyContacts: Bool { !viewModel.repository.contacts.isEmpty }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if !hasAnyContacts {
                VStack(spacing: AppTheme.spacingMedium) {
                    Spacer()
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("No contacts yet")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("Import your contacts or add one manually.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Add Contact") {
                        showingAddContact = true
                    }
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: 260)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(AppTheme.accent)
                    )
                    .buttonStyle(PressScaleButtonStyle())
                    Spacer()
                }
                .padding(.horizontal, AppTheme.spacingLarge)
            } else {
                VStack(spacing: AppTheme.spacingMedium) {
                    HStack(spacing: AppTheme.spacingSmall) {
                        Image(systemName: "magnifyingglass")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        TextField("Search contacts", text: $viewModel.searchText)
                            .focused($isSearchFocused)
                            .textInputAutocapitalization(.words)

                        if !viewModel.searchText.isEmpty {
                            Button {
                                viewModel.searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(PressScaleButtonStyle())
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.inputCornerRadius, style: .continuous)
                            .fill(Color(uiColor: .secondarySystemBackground))
                    )

                    Group {
                        if viewModel.filteredContacts.isEmpty {
                            ContentUnavailableView(
                                "No Results",
                                systemImage: "magnifyingglass",
                                description: Text("No contacts match your search.")
                            )
                        } else {
                            List {
                                ForEach(viewModel.filteredContacts) { contact in
                                    NavigationLink(value: contact) {
                                        ContactRowView(contact: contact)
                                    }
                                    .buttonStyle(.plain)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
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
                }
                .padding(.horizontal, AppTheme.spacingMedium)
                .padding(.top, AppTheme.spacingMedium)
            }

            if hasAnyContacts {
                Button {
                    showingAddContact = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(Circle().fill(AppTheme.accent))
                        .shadow(color: .black.opacity(0.22), radius: 12, x: 0, y: 6)
                }
                .buttonStyle(PressScaleButtonStyle())
                .padding(.trailing, AppTheme.spacingMedium)
                .padding(.bottom, AppTheme.spacingLarge)
                .accessibilityLabel("Add Contact")
            }
        }
        .background(Color(uiColor: .systemBackground))
        .navigationTitle("Contacts")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Import") {
                    showingImportDialog = true
                }
                .foregroundStyle(AppTheme.accent)
                .buttonStyle(PressScaleButtonStyle())
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
        .fullScreenCover(isPresented: $showingContactPicker) {
            ContactPickerSheet(
                onSelect: { contacts in
                    Task {
                        await importSelectedContacts(contacts)
                    }
                },
                onCancel: {
                    showingContactPicker = false
                }
            )
            .ignoresSafeArea()
        }
        .confirmationDialog("Import Contacts", isPresented: $showingImportDialog) {
            Button("Select Contacts") {
                Task {
                    await prepareContactPicker()
                }
            }

            Button("Cancel", role: .cancel) {}
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
        var existingEmails = Set(
            viewModel.repository.contacts.compactMap { normalizedEmail($0.email) }
        )
        var existingPhones = Set(
            viewModel.repository.contacts.compactMap { normalizedPhone($0.phone) }
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
            viewModel.addContact(contact)
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
        CardContainer {
            HStack(spacing: AppTheme.spacingMedium) {
                avatar

                VStack(alignment: .leading, spacing: 6) {
                    Text(contact.fullName.isEmpty ? "No Name" : contact.fullName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary.opacity(0.5))
            }
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(contact.relationshipType.color.opacity(0.8))
                .frame(width: 4)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                .padding(.vertical, 6)
                .padding(.leading, 2)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 1)
                .padding(.horizontal, 6)
        }
    }

    @ViewBuilder
    private var avatar: some View {
        if let avatarPath = contact.avatarPath,
           let uiImage = UIImage(contentsOfFile: avatarPath)
        {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .strokeBorder(contact.relationshipType.color.opacity(0.45), lineWidth: 1)
                }
        } else {
            Text(contact.initials.isEmpty ? "?" : contact.initials)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(contact.relationshipType.color)
                .frame(width: 52, height: 52)
                .background(
                    Circle()
                        .fill(contact.relationshipType.color.opacity(0.2))
                )
        }
    }
}
