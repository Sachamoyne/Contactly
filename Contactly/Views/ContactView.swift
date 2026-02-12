import SwiftUI

struct ContactView: View {
    let contact: Contact
    var viewModel: ContactsViewModel
    @State private var showingEdit = false
    @Environment(\.dismiss) private var dismiss

    private var currentContact: Contact {
        viewModel.repository.contacts.first { $0.id == contact.id } ?? contact
    }

    var body: some View {
        List {
            // MARK: Header
            Section {
                VStack(spacing: 12) {
                    AvatarView(contact: currentContact, size: 80)

                    Text(currentContact.fullName.isEmpty ? "No Name" : currentContact.fullName)
                        .font(.title2)
                        .fontWeight(.bold)

                    if !currentContact.company.isEmpty {
                        Text(currentContact.company)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            // MARK: Contact Info
            if !currentContact.phone.isEmpty || !currentContact.email.isEmpty {
                Section("Contact Info") {
                    if !currentContact.phone.isEmpty {
                        HStack {
                            Label("Phone", systemImage: "phone")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(currentContact.phone)
                        }
                    }
                    if !currentContact.email.isEmpty {
                        HStack {
                            Label("Email", systemImage: "envelope")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(currentContact.email)
                        }
                    }
                }
            }

            // MARK: Tags
            if !currentContact.tags.isEmpty {
                Section("Tags") {
                    FlowLayout(spacing: 8) {
                        ForEach(currentContact.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.blue.opacity(0.1))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            // MARK: Notes
            if !currentContact.notes.isEmpty {
                Section("Notes") {
                    Text(currentContact.notes)
                        .font(.body)
                }
            }

            // MARK: Details
            Section("Details") {
                LabeledContent(
                    "Added",
                    value: currentContact.createdAt.formatted(date: .abbreviated, time: .omitted)
                )

                if let lastInteraction = currentContact.lastInteractionDate {
                    LabeledContent(
                        "Last Interaction",
                        value: lastInteraction.formatted(date: .abbreviated, time: .omitted)
                    )
                }
            }
        }
        .navigationTitle("Contact")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showingEdit = true
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            EditContactView(viewModel: viewModel, contact: currentContact)
        }
    }
}
