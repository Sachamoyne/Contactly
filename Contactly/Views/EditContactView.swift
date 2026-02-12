import PhotosUI
import SwiftUI
import UIKit

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
    @State private var avatarPath: String?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedAvatarImage: UIImage?

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
        _avatarPath = State(initialValue: contact?.avatarPath)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: AppTheme.spacingSmall) {
                        avatarPreview

                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Text("Add Photo")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.accent)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(AppTheme.chipBackground)
                                )
                        }

                        if avatarPath != nil {
                            Button("Remove Photo", role: .destructive) {
                                selectedAvatarImage = nil
                                avatarPath = nil
                            }
                            .font(.footnote)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                Section("Name") {
                    TextField("First Name", text: $firstName)
                        .textContentType(.givenName)
                    TextField("Last Name", text: $lastName)
                        .textContentType(.familyName)
                }

                Section("Company") {
                    TextField("Company", text: $company)
                        .textContentType(.organizationName)
                }

                Section("Contact Info") {
                    TextField("Phone", text: $phone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }

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
                                .background(AppTheme.chipBackground)
                                .foregroundStyle(AppTheme.accent)
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.bottom, 4)
                    }

                    HStack {
                        TextField("Add tag", text: $newTag)
                            .textInputAutocapitalization(.never)
                            .onSubmit(addTag)

                        Button(action: addTag) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(AppTheme.accent)
                        }
                        .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

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
                        .foregroundStyle(AppTheme.accent)
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    await loadSelectedImage(from: newItem)
                }
            }
        }
    }

    private var avatarPreview: some View {
        Group {
            if let selectedAvatarImage {
                Image(uiImage: selectedAvatarImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
            } else if let avatarPath, let image = UIImage(contentsOfFile: avatarPath) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(AppTheme.tintBackground)
                    .frame(width: 100, height: 100)
                    .overlay {
                        Text(initialsText)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                    }
            }
        }
        .overlay {
            Circle()
                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
        }
    }

    private var initialsText: String {
        let fallback = "\(firstName.prefix(1))\(lastName.prefix(1))".trimmingCharacters(in: .whitespacesAndNewlines)
        return fallback.isEmpty ? "?" : fallback.uppercased()
    }

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }
        withAnimation {
            tags.append(trimmed)
        }
        newTag = ""
    }

    private func loadSelectedImage(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data)
        else { return }

        await MainActor.run {
            selectedAvatarImage = image
        }
    }

    private func saveContact() {
        let contactID = existingContact?.id ?? UUID()
        var finalAvatarPath = avatarPath

        if let selectedAvatarImage {
            finalAvatarPath = persistAvatarImage(selectedAvatarImage, for: contactID)
        }

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
            updated.avatarPath = finalAvatarPath
            viewModel.updateContact(updated)
        } else {
            let contact = Contact(
                id: contactID,
                firstName: firstName.trimmingCharacters(in: .whitespaces),
                lastName: lastName.trimmingCharacters(in: .whitespaces),
                company: company.trimmingCharacters(in: .whitespaces),
                email: email.trimmingCharacters(in: .whitespaces),
                phone: phone.trimmingCharacters(in: .whitespaces),
                notes: notes,
                tags: tags,
                avatarPath: finalAvatarPath,
                lastInteractionDate: hasLastInteraction ? (lastInteractionDate ?? Date()) : nil
            )
            viewModel.addContact(contact)
        }
        dismiss()
    }

    private func persistAvatarImage(_ image: UIImage, for contactID: UUID) -> String? {
        guard let jpegData = image.jpegData(compressionQuality: 0.85) else {
            return avatarPath
        }

        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("ContactPhotos", isDirectory: true)

        guard let directory else {
            return avatarPath
        }

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("\(contactID.uuidString).jpg")
            try jpegData.write(to: url, options: .atomic)
            return url.path
        } catch {
            return avatarPath
        }
    }
}

