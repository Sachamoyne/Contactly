import SwiftUI

struct EditContactView: View {
    var viewModel: ContactsViewModel
    @Environment(\.dismiss) private var dismiss

    private let existingContact: Contact?

    @State private var firstName: String
    @State private var lastName: String
    @State private var company: String
    @State private var phone: String
    @State private var email: String
    @State private var notes: String
    @State private var tags: [String]
    @State private var newTag: String = ""
    @State private var lastInteractionDate: Date?
    @State private var hasLastInteraction: Bool

    private var isNameEmpty: Bool {
        firstName.trimmingCharacters(in: .whitespaces).isEmpty
            && lastName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    init(viewModel: ContactsViewModel, contact: Contact? = nil) {
        self.viewModel = viewModel
        self.existingContact = contact
        _firstName = State(initialValue: contact?.firstName ?? "")
        _lastName = State(initialValue: contact?.lastName ?? "")
        _company = State(initialValue: contact?.company ?? "")
        _phone = State(initialValue: contact?.phone ?? "")
        _email = State(initialValue: contact?.email ?? "")
        _notes = State(initialValue: contact?.notes ?? "")
        _tags = State(initialValue: contact?.tags ?? [])
        _lastInteractionDate = State(initialValue: contact?.lastInteractionDate)
        _hasLastInteraction = State(initialValue: contact?.lastInteractionDate != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Name
                Section("Name") {
                    TextField("First Name", text: $firstName)
                        .textContentType(.givenName)
                    TextField("Last Name", text: $lastName)
                        .textContentType(.familyName)
                }

                // MARK: Company
                Section("Company") {
                    TextField("Company", text: $company)
                        .textContentType(.organizationName)
                }

                // MARK: Contact Info
                Section("Contact Info") {
                    TextField("Phone", text: $phone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }

                // MARK: Tags
                Section("Tags") {
                    if !tags.isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(tags, id: \.self) { tag in
                                HStack(spacing: 4) {
                                    Text(tag)
                                        .font(.subheadline)
                                    Button {
                                        withAnimation {
                                            tags.removeAll { $0 == tag }
                                        }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.blue.opacity(0.1))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                            }
                        }
                    }

                    HStack {
                        TextField("Add tag", text: $newTag)
                            .textInputAutocapitalization(.never)
                            .onSubmit(addTag)

                        Button(action: addTag) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.blue)
                        }
                        .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                // MARK: Last Interaction
                Section("Last Interaction") {
                    Toggle("Track Last Interaction", isOn: $hasLastInteraction.animation())

                    if hasLastInteraction {
                        DatePicker(
                            "Date",
                            selection: Binding(
                                get: { lastInteractionDate ?? Date() },
                                set: { lastInteractionDate = $0 }
                            ),
                            displayedComponents: .date
                        )
                    }
                }

                // MARK: Notes
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle(existingContact == nil ? "New Contact" : "Edit Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: saveContact)
                        .disabled(isNameEmpty)
                }
            }
        }
    }

    // MARK: - Actions

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }
        withAnimation {
            tags.append(trimmed)
        }
        newTag = ""
    }

    private func saveContact() {
        if let existing = existingContact {
            var updated = existing
            updated.firstName = firstName.trimmingCharacters(in: .whitespaces)
            updated.lastName = lastName.trimmingCharacters(in: .whitespaces)
            updated.company = company.trimmingCharacters(in: .whitespaces)
            updated.phone = phone.trimmingCharacters(in: .whitespaces)
            updated.email = email.trimmingCharacters(in: .whitespaces)
            updated.notes = notes
            updated.tags = tags
            updated.lastInteractionDate = hasLastInteraction ? (lastInteractionDate ?? Date()) : nil
            viewModel.updateContact(updated)
        } else {
            let contact = Contact(
                firstName: firstName.trimmingCharacters(in: .whitespaces),
                lastName: lastName.trimmingCharacters(in: .whitespaces),
                company: company.trimmingCharacters(in: .whitespaces),
                email: email.trimmingCharacters(in: .whitespaces),
                phone: phone.trimmingCharacters(in: .whitespaces),
                notes: notes,
                tags: tags,
                lastInteractionDate: hasLastInteraction ? (lastInteractionDate ?? Date()) : nil
            )
            viewModel.addContact(contact)
        }
        dismiss()
    }
}
