import SwiftUI

struct PrepMeetingView: View {
    let meeting: MeetingEvent
    let contact: Contact?
    var interactionRepository: InteractionRepository
    var onLinkToContact: (() -> Void)? = nil

    @State private var showingAddNote = false
    @State private var showingAddInteraction = false

    private var recentInteractions: [Interaction] {
        guard let contact else { return [] }
        return interactionRepository.getContactTimeline(contactId: contact.id, limit: 3)
    }

    private var daysSinceLastInteraction: Int? {
        guard let contact else { return nil }
        return contact.daysSinceLastInteraction(from: recentInteractions)
    }

    private var interactionFrequencyDays: Int? {
        guard let contact else { return nil }
        return contact.interactionFrequencyDays(from: recentInteractions)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(contact?.fullName.isEmpty == false ? (contact?.fullName ?? "") : "Unknown contact")
                        .font(.title2.weight(.bold))

                    Text(meeting.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("\(DateUtils.formatDate(meeting.startDate)) • \(meeting.startDate.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Insights")
                        .font(.headline)

                    if contact == nil {
                        Text("No linked contact for this event.")
                            .foregroundStyle(.secondary)
                    } else {
                        if let days = daysSinceLastInteraction {
                            Text("Last interaction: \(DateUtils.formatRelativeDays(days))")
                        }

                        if let freq = interactionFrequencyDays {
                            Text("Frequency: ~ every \(freq) days")
                        }

                        if daysSinceLastInteraction == nil && interactionFrequencyDays == nil {
                            Text("No interactions yet.")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.headline)

                    if let contact,
                       !contact.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    {
                        Text(contact.notes)
                    } else {
                        Text("No notes yet.")
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent interactions")
                        .font(.headline)

                    if recentInteractions.isEmpty {
                        Text("No interactions yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(recentInteractions) { interaction in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(DateUtils.formatDate(interaction.date))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(interaction.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? interaction.title : interaction.notes)
                                    .font(.subheadline)
                            }
                        }
                    }
                }

                Divider()

                if let contact {
                    HStack(spacing: 12) {
                        Button("Add note") {
                            showingAddNote = true
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Add interaction") {
                            showingAddInteraction = true
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    Button("Link to contact") {
                        onLinkToContact?()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .navigationTitle("Prep Meeting")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddNote) {
            if let contact {
                AddInteractionView(
                    contact: contact,
                    interactionRepository: interactionRepository,
                    preferredType: .note
                )
            }
        }
        .sheet(isPresented: $showingAddInteraction) {
            if let contact {
                AddInteractionView(
                    contact: contact,
                    interactionRepository: interactionRepository
                )
            }
        }
    }
}
