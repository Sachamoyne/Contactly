import SwiftUI

struct ContactView: View {
    let contact: Contact
    var viewModel: ContactsViewModel
    @Bindable var interactionRepository: InteractionRepository
    @Environment(\.openURL) private var openURL
    @State private var showingEdit = false
    @State private var showingAddInteractionSheet = false

    private var currentContact: Contact {
        viewModel.repository.contacts.first { $0.id == contact.id } ?? contact
    }

    private var timelineInteractions: [Interaction] {
        interactionRepository.getContactTimeline(contactId: currentContact.id, limit: 50)
    }

    private var lastInteraction: Interaction? {
        timelineInteractions.first
    }

    private var hasInteractions: Bool {
        !timelineInteractions.isEmpty
    }

    private var latestInteractionDate: Date? {
        timelineInteractions.map(\.date).max()
    }

    private var relationshipStatus: (status: String, daysSince: Int?) {
        interactionRepository.getRelationshipStatus(for: currentContact.id)
    }

    private var relationshipType: RelationshipType {
        currentContact.relationshipType
    }

    private var relationshipColor: Color {
        relationshipType.color
    }

    private var visibleImportantInformation: [ImportantInfo] {
        currentContact.importantInformation.filter { info in
            switch info.type {
            case .birthday:
                return true
            case .interest, .spouse, .children:
                return !info.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        }
    }

    var body: some View {
        List {
            // MARK: Header
            Section {
                VStack(spacing: 14) {
                    AvatarView(contact: currentContact, size: 80)

                    Text(currentContact.fullName.isEmpty ? "No Name" : currentContact.fullName)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(relationshipType.displayName.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(relationshipType.color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(relationshipType.color.opacity(0.14))
                        )

                    if !currentContact.company.isEmpty {
                        Text(currentContact.company)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Button(action: {
                        showingAddInteractionSheet = true
                    }) {
                        Label(hasInteractions ? "Add Interaction" : "Add first interaction", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .labelStyle(.titleOnly)

                    HStack(spacing: 18) {
                        quickActionButton(systemImage: "phone.fill", isEnabled: !currentContact.phone.isEmpty) {
                            callPhoneNumber(currentContact.phone)
                        }

                        quickActionButton(systemImage: "message.fill", isEnabled: !currentContact.phone.isEmpty) {
                            messagePhoneNumber(currentContact.phone)
                        }

                        quickActionButton(systemImage: "envelope.fill", isEnabled: !currentContact.email.isEmpty) {
                            openEmail(currentContact.email)
                        }
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                        .fill(relationshipType.color.opacity(0.05))
                )
                .listRowBackground(Color.clear)
                .padding(.vertical, 8)
            }

            Section {
                if let daysSince = relationshipStatus.daysSince {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .strokeBorder(relationshipType.color.opacity(0.45), lineWidth: 1)
                                    .frame(width: 10, height: 10)
                                Circle()
                                    .fill(relationshipColor)
                                    .frame(width: 6, height: 6)
                            }

                            Text(relationshipStatus.status)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(.primary)
                        }

                        Text("Last contact: \(daysSince) day\(daysSince == 1 ? "" : "s") ago")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                } else {
                    Text("Log your first interaction to start building your relationship history.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Relationship")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(relationshipType.color.opacity(0.85))
                    .textCase(nil)
            }

            Section {
                if let lastInteraction {
                    lastInteractionCard(lastInteraction)
                } else {
                    Text("No interactions yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                NavigationLink {
                    ContactTimelineView(
                        contact: currentContact,
                        interactionRepository: interactionRepository
                    )
                } label: {
                    HStack {
                        Text("View timeline")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            } header: {
                Text("Last interaction")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(relationshipType.color.opacity(0.85))
                    .textCase(nil)
            }

            if !visibleImportantInformation.isEmpty {
                Section("Important information") {
                    ForEach(visibleImportantInformation) { info in
                        LabeledContent(info.type.displayName, value: formattedImportantInformationValue(info))
                    }
                }
            }

            // MARK: Tags
            if !currentContact.tags.isEmpty {
                Section("Tags") {
                    FlowLayout(spacing: 8) {
                        ForEach(currentContact.tags, id: \.self) { tag in
                            TagChip(text: tag)
                        }
                    }
                }
            }

            // MARK: Notes
            if !currentContact.notes.isEmpty {
                Section {
                    Text(currentContact.notes)
                        .font(.body)
                } header: {
                    Text("Notes")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(relationshipType.color.opacity(0.85))
                        .textCase(nil)
                }
            }

            // MARK: Details
            Section("Details") {
                LabeledContent(
                    "Added",
                    value: currentContact.createdAt.formatted(date: .abbreviated, time: .omitted)
                )

                if let birthday = currentContact.birthday {
                    LabeledContent(
                        "Birthday",
                        value: birthday.formatted(date: .abbreviated, time: .omitted)
                    )
                }

                if let lastInteraction = latestInteractionDate {
                    LabeledContent(
                        "Last Interaction",
                        value: lastInteraction.formatted(date: .abbreviated, time: .omitted)
                    )
                }
            }
        }
        .listSectionSpacing(AppTheme.spacingLarge)
        .navigationTitle("Contact")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showingEdit = true
                }
                .foregroundStyle(AppTheme.accent)
            }
        }
        .sheet(isPresented: $showingEdit) {
            EditContactView(
                viewModel: viewModel,
                interactionRepository: interactionRepository,
                contact: currentContact
            )
        }
        .sheet(isPresented: $showingAddInteractionSheet) {
            AddInteractionView(
                contact: currentContact,
                interactionRepository: interactionRepository
            )
        }
    }

    private func lastInteractionCard(_ interaction: Interaction) -> some View {
        let displayText: String = {
            let content = interaction.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            if !content.isEmpty { return content }

            let title = interaction.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty { return title }

            return "Interaction"
        }()

        return VStack(alignment: .leading, spacing: 10) {
            Text(interaction.date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(displayText)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func callPhoneNumber(_ value: String) {
        let digits = normalizedPhoneNumber(value)
        guard !digits.isEmpty, let url = URL(string: "tel://\(digits)") else { return }
        openURL(url)
    }

    private func messagePhoneNumber(_ value: String) {
        let digits = normalizedPhoneNumber(value)
        guard !digits.isEmpty, let url = URL(string: "sms://\(digits)") else { return }
        openURL(url)
    }

    private func openEmail(_ value: String) {
        let email = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty, let url = URL(string: "mailto:\(email)") else { return }
        openURL(url)
    }

    private func normalizedPhoneNumber(_ value: String) -> String {
        value.filter { $0.isNumber || $0 == "+" }
    }

    private func formattedImportantInformationValue(_ info: ImportantInfo) -> String {
        switch info.type {
        case .birthday:
            if let date = birthdayStorageFormatter.date(from: info.value) {
                return date.formatted(.dateTime.day().month(.abbreviated))
            }
            return info.value
        case .interest, .spouse, .children:
            return info.value
        }
    }

    private var birthdayStorageFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    @ViewBuilder
    private func quickActionButton(systemImage: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isEnabled ? AppTheme.accent : .secondary)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(isEnabled ? AppTheme.tintBackground : AppTheme.chipBackground)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(systemImage)
    }
}
