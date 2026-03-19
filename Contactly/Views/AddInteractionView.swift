import SwiftUI

struct AddInteractionView: View {
    private let meeting: MeetingEvent?
    let contact: Contact
    var interactionRepository: InteractionRepository

    @Environment(\.dismiss) private var dismiss

    @State private var interactionDate: Date
    @State private var interactionType: InteractionKind
    @State private var notes: String = ""
    @State private var hasFollowUpDate = false
    @State private var followUpDate = Date()

    var onSaved: (() -> Void)?

    enum InteractionKind: String, CaseIterable, Identifiable {
        case note
        case general
        case call
        case email
        case message
        case inPerson

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .note:
                return "Note"
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

        var modelType: InteractionType {
            switch self {
            case .note:
                return .note
            case .call:
                return .call
            case .message, .email:
                return .message
            case .general, .inPerson:
                return .other
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
        preferredType: InteractionKind = .general,
        onSaved: (() -> Void)? = nil
    ) {
        self.meeting = nil
        self.contact = contact
        self.interactionRepository = interactionRepository
        self.onSaved = onSaved
        _interactionDate = State(initialValue: Date())
        _interactionType = State(initialValue: preferredType)
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
                            ForEach(InteractionKind.allCases) { type in
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
        let interactionModelType: InteractionType = meeting == nil ? interactionType.modelType : .meeting
        let title = meeting == nil ? interactionType.displayName : "Meeting"
        let startDate = meeting?.startDate ?? interactionDate
        let endDate = meeting?.endDate ?? interactionDate

        let interaction = Interaction(
            contactId: contact.id,
            type: interactionModelType,
            date: startDate,
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
