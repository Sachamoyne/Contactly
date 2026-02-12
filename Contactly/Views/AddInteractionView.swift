import SwiftUI

struct AddInteractionView: View {
    let meeting: MeetingEvent
    let contact: Contact
    var interactionRepository: InteractionRepository

    @Environment(\.dismiss) private var dismiss

    @State private var notes: String = ""
    @State private var hasFollowUpDate = false
    @State private var followUpDate = Date()

    var onSaved: (() -> Void)?

    var body: some View {
        NavigationStack {
            Form {
                Section("Meeting") {
                    LabeledContent("Contact", value: contact.fullName)
                    LabeledContent("Title", value: meeting.title)
                    LabeledContent("Start", value: meeting.startDate.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("End", value: meeting.endDate.formatted(date: .abbreviated, time: .shortened))
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 140)
                }

                Section("Follow-up") {
                    Toggle("Set follow-up date", isOn: $hasFollowUpDate.animation())
                    if hasFollowUpDate {
                        DatePicker("Date", selection: $followUpDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }
            }
            .navigationTitle("Meeting Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveInteraction()
                    }
                    .disabled(notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .foregroundStyle(AppTheme.accent)
                }
            }
        }
    }

    private func saveInteraction() {
        let interaction = Interaction(
            contactId: contact.id,
            eventId: meeting.id,
            title: meeting.title,
            startDate: meeting.startDate,
            endDate: meeting.endDate,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            followUpDate: hasFollowUpDate ? followUpDate : nil,
            tagsSnapshot: contact.tags
        )

        interactionRepository.add(interaction)
        onSaved?()
        dismiss()
    }
}

