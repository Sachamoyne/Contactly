import SwiftUI

struct ContactView: View {
    let contact: Contact
    var viewModel: ContactsViewModel
    @Bindable var interactionRepository: InteractionRepository
    @State private var showingEdit = false
    @Environment(\.dismiss) private var dismiss

    private var currentContact: Contact {
        viewModel.repository.contacts.first { $0.id == contact.id } ?? contact
    }

    private static let timelineDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()

    private var timelineInteractions: [Interaction] {
        interactionRepository.getInteractions(for: currentContact.id)
    }

    private var relationshipStatus: (status: String, daysSince: Int?) {
        interactionRepository.getRelationshipStatus(for: currentContact.id)
    }

    private var relationshipColor: Color {
        switch relationshipStatus.status {
        case "Strong":
            return .green
        case "Medium":
            return .orange
        case "Weak":
            return .red
        default:
            return .secondary
        }
    }

    private func formattedTimelineDate(_ date: Date) -> String {
        Self.timelineDateFormatter.string(from: date)
    }

    private func notesPreview(_ notes: String) -> String {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 120 else { return trimmed }
        return "\(trimmed.prefix(120))..."
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
                .padding(.vertical, 8)
            }

            Section("Relationship") {
                if let daysSince = relationshipStatus.daysSince {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(relationshipColor)
                                .frame(width: 10, height: 10)

                            Text(relationshipStatus.status)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                        }

                        Text("Last contact: \(daysSince) day\(daysSince == 1 ? "" : "s") ago")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                } else {
                    Text("No interactions recorded")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Timeline") {
                if timelineInteractions.isEmpty {
                    Text("No meetings recorded yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(timelineInteractions) { interaction in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(formattedTimelineDate(interaction.startDate))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Spacer()
                            }

                            Text(interaction.title)
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Text(notesPreview(interaction.notes))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)

                            if let followUpDate = interaction.followUpDate {
                                Text("Follow-up: \(formattedTimelineDate(followUpDate))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(Color(.tertiarySystemFill))
                                    )
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                        .listRowSeparator(.hidden)
                    }
                }
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
                .foregroundStyle(AppTheme.accent)
            }
        }
        .sheet(isPresented: $showingEdit) {
            EditContactView(viewModel: viewModel, contact: currentContact)
        }
    }
}
