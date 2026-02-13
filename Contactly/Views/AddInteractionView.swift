import SwiftUI

struct AddInteractionView: View {
    private let meeting: MeetingEvent?
    let contact: Contact
    var interactionRepository: InteractionRepository

    @Environment(\.dismiss) private var dismiss

    @State private var interactionDate: Date
    @State private var interactionType: InteractionType
    @State private var notes: String = ""
    @State private var hasFollowUpDate = false
    @State private var followUpDate = Date()

    var onSaved: (() -> Void)?

    enum InteractionType: String, CaseIterable, Identifiable {
        case general
        case call
        case email
        case message
        case inPerson

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .general:
                return "General"
            case .call:
                return "Call"
            case .email:
                return "Email"
            case .message:
                return "Message"
            case .inPerson:
                return "In Person"
            }
        }
    }

    init(
        meeting: MeetingEvent,
        contact: Contact,
        interactionRepository: InteractionRepository,
        onSaved: (() -> Void)? = nil
    ) {
        self.meeting = meeting
        self.contact = contact
        self.interactionRepository = interactionRepository
        self.onSaved = onSaved
        _interactionDate = State(initialValue: meeting.startDate)
        _interactionType = State(initialValue: .general)
    }

    init(
        contact: Contact,
        interactionRepository: InteractionRepository,
        onSaved: (() -> Void)? = nil
    ) {
        self.meeting = nil
        self.contact = contact
        self.interactionRepository = interactionRepository
        self.onSaved = onSaved
        _interactionDate = State(initialValue: Date())
        _interactionType = State(initialValue: .general)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Interaction") {
                    LabeledContent("Contact", value: contact.fullName)
                    if let meeting {
                        LabeledContent("Title", value: meeting.title)
                        LabeledContent("Start", value: meeting.startDate.formatted(date: .abbreviated, time: .shortened))
                        LabeledContent("End", value: meeting.endDate.formatted(date: .abbreviated, time: .shortened))
                    } else {
                        DatePicker("Date", selection: $interactionDate, displayedComponents: [.date, .hourAndMinute])
                        Picker("Type", selection: $interactionType) {
                            ForEach(InteractionType.allCases) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                    }
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
            .navigationTitle("Add Interaction")
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
        let title = meeting?.title ?? interactionType.displayName
        let startDate = meeting?.startDate ?? interactionDate
        let endDate = meeting?.endDate ?? interactionDate

        let interaction = Interaction(
            contactId: contact.id,
            eventId: meeting?.id,
            title: title,
            startDate: startDate,
            endDate: endDate,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            followUpDate: hasFollowUpDate ? followUpDate : nil,
            tagsSnapshot: contact.tags
        )

        withAnimation(.easeInOut(duration: 0.2)) {
            interactionRepository.add(interaction)
        }
        onSaved?()
        dismiss()
    }
}
