import SwiftUI

struct ContactTimelineView: View {
    let contact: Contact
    @Bindable var interactionRepository: InteractionRepository

    private var timelineInteractions: [Interaction] {
        interactionRepository.getContactTimeline(contactId: contact.id, limit: 50)
    }

    var body: some View {
        List {
            Section {
                if timelineInteractions.isEmpty {
                    Text("No interactions yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(timelineInteractions) { interaction in
                        NavigationLink {
                            EditInteractionContainer(
                                contact: contact,
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
                    .foregroundStyle(contact.relationshipType.color.opacity(0.85))
                    .textCase(nil)
            }
        }
        .listSectionSpacing(AppTheme.spacingLarge)
        .navigationTitle("Timeline")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func interactionCard(_ interaction: Interaction) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(interaction.date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Text(interaction.type.displayName.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.secondary.opacity(0.12))
                    )

                Text(interaction.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            if !interaction.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(interaction.notes)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

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
