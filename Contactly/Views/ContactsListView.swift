import SwiftUI

struct ContactsListView: View {
    @Bindable var viewModel: ContactsViewModel
    @State private var showingAddContact = false

    var body: some View {
        NavigationStack {
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
                ToolbarItem(placement: .primaryAction) {
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
        }
    }
}

// MARK: - Contact Row

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
