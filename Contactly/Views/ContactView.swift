import SwiftUI

struct ContactView: View {
    let contact: Contact
    var viewModel: ContactsViewModel
    @Bindable var interactionRepository: InteractionRepository
    @State private var showingEdit = false
    @State private var showingAddInteractionSheet = false

    private var currentContact: Contact {
        viewModel.repository.contacts.first { $0.id == contact.id } ?? contact
    }

    private var timelineInteractions: [Interaction] {
        interactionRepository.getInteractions(for: currentContact.id)
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

    private var emptyTimelineMessage: String {
        switch relationshipType {
        case .pro:
            return "Log your first interaction to start building this relationship."
        case .perso:
            return "Add a memory or interaction to keep in touch."
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
                        Label("Add Interaction", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
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
                if timelineInteractions.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "text.bubble")
                            .font(.title3)
                            .foregroundStyle(.secondary)

                        Text("No interactions yet")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text(emptyTimelineMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Button("Add first interaction") {
                            showingAddInteractionSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                } else {
                    ForEach(timelineInteractions) { interaction in
                        NavigationLink {
                            EditInteractionContainer(
                                contact: currentContact,
                                interaction: interaction,
                                interactionRepository: interactionRepository
                            )
                        } label: {
                            interactionCard(interaction)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    interactionRepository.delete(interaction)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
            } header: {
                Text("Timeline")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(relationshipType.color.opacity(0.85))
                    .textCase(nil)
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

                if let lastInteraction = currentContact.lastInteractionDate {
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
            EditContactView(viewModel: viewModel, contact: currentContact)
        }
        .sheet(isPresented: $showingAddInteractionSheet) {
            AddInteractionView(
                contact: currentContact,
                interactionRepository: interactionRepository
            )
        }
    }

    private func interactionCard(_ interaction: Interaction) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(interaction.startDate.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(interaction.notes)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let followUp = interaction.followUpDate {
                Text("Follow up: \(followUp.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.orange.opacity(0.14))
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .fadeInOnAppear()
    }
}

private struct EditInteractionContainer: View {
    let contact: Contact
    var interaction: Interaction
    @Bindable var interactionRepository: InteractionRepository
    @State private var editableInteraction: Interaction

    init(contact: Contact, interaction: Interaction, interactionRepository: InteractionRepository) {
        self.contact = contact
        self.interaction = interaction
        self.interactionRepository = interactionRepository
        _editableInteraction = State(initialValue: interaction)
    }

    var body: some View {
        EditInteractionView(
            contact: contact,
            interaction: $editableInteraction,
            onSave: { updatedInteraction in
                interactionRepository.update(updatedInteraction)
            },
            onDelete: { interactionToDelete in
                interactionRepository.delete(interactionToDelete)
            }
        )
    }
}
