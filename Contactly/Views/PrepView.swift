import SwiftUI

struct PrepView: View {
    let meeting: MeetingEvent
    let contact: Contact
    @Bindable var interactionRepository: InteractionRepository

    @State private var showingAddInteraction = false

    private var lastInteraction: Interaction? {
        interactionRepository.listByContact(contactId: contact.id).first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.spacingLarge) {
                headerCard
                lastMeetingCard
                allNotesCard
                quickFieldsCard
            }
            .padding(AppTheme.spacingMedium)
        }
        .background(Color(uiColor: .systemBackground))
        .navigationTitle("Prep")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add meeting notes") {
                    showingAddInteraction = true
                }
                .foregroundStyle(AppTheme.accent)
            }
        }
        .sheet(isPresented: $showingAddInteraction) {
            AddInteractionView(
                meeting: meeting,
                contact: contact,
                interactionRepository: interactionRepository
            )
        }
    }

    private var headerCard: some View {
        HStack(spacing: AppTheme.spacingMedium) {
            AvatarView(contact: contact, size: 72)

            VStack(alignment: .leading, spacing: 6) {
                Text(contact.fullName.isEmpty ? "Unknown Contact" : contact.fullName)
                    .font(.title3.weight(.bold))

                if !contact.company.isEmpty {
                    Text(contact.company)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if !contact.tags.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(contact.tags, id: \.self) { tag in
                            TagChip(text: tag)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(AppTheme.spacingMedium)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private var lastMeetingCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Last Meeting Notes")
                .font(.headline)

            if let lastInteraction {
                Text(lastInteraction.startDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(lastInteraction.notes)
                    .font(.body)

                if let followUp = lastInteraction.followUpDate {
                    Text("Follow-up: \(followUp.formatted(date: .abbreviated, time: .shortened))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No previous interaction logged.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(AppTheme.spacingMedium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private var allNotesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("All Notes")
                .font(.headline)

            if contact.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("No contact notes yet.")
                    .foregroundStyle(.secondary)
            } else {
                Text(contact.notes)
                    .font(.body)
            }
        }
        .padding(AppTheme.spacingMedium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private var quickFieldsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Fields")
                .font(.headline)

            LabeledContent("Last discussed", value: derivedLastDiscussed)
            LabeledContent("Next action", value: derivedNextAction)
        }
        .padding(AppTheme.spacingMedium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private var derivedLastDiscussed: String {
        guard let notes = lastInteraction?.notes.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty else {
            return "N/A"
        }
        return notes.split(separator: "\n").first.map(String.init) ?? notes
    }

    private var derivedNextAction: String {
        guard let notes = lastInteraction?.notes.lowercased(), !notes.isEmpty else {
            return "N/A"
        }

        if let nextLine = notes
            .split(separator: "\n")
            .map(String.init)
            .first(where: { $0.contains("next") || $0.contains("follow") || $0.contains("action") })
        {
            return nextLine
        }

        return "N/A"
    }
}

