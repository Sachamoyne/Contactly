import SwiftUI

struct ManualMeetingCreationView: View {
    let contacts: [Contact]
    let existingMeeting: ManualMeeting?
    let existingContact: Contact?
    var onSave: (UUID, Date, String, String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedContactID: UUID?
    @State private var selectedDate: Date
    @State private var selectedTime: Date
    @State private var occasion: String
    @State private var notes: String

    init(
        contacts: [Contact],
        existingMeeting: ManualMeeting? = nil,
        existingContact: Contact? = nil,
        onSave: @escaping (UUID, Date, String, String) -> Void
    ) {
        self.contacts = contacts
        self.existingMeeting = existingMeeting
        self.existingContact = existingContact
        self.onSave = onSave

        let baseDate = existingMeeting?.date ?? Date()
        _selectedContactID = State(initialValue: existingMeeting?.contactID ?? existingContact?.id ?? contacts.first?.id)
        _selectedDate = State(initialValue: baseDate)
        _selectedTime = State(initialValue: baseDate)
        _occasion = State(initialValue: existingMeeting?.occasion ?? "")
        _notes = State(initialValue: existingMeeting?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Contact") {
                    Picker("Select Contact", selection: $selectedContactID) {
                        ForEach(contacts) { contact in
                            Text(contact.fullName.isEmpty ? "No Name" : contact.fullName)
                                .tag(Optional(contact.id))
                        }
                    }
                }

                Section("When") {
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                    DatePicker("Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                }

                Section("Occasion") {
                    TextField("Client catch-up", text: $occasion)
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle(existingMeeting == nil ? "New Manual Meeting" : "Edit Manual Meeting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        selectedContactID != nil && !occasion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        guard let selectedContactID else { return }
        onSave(
            selectedContactID,
            combinedDate(),
            occasion.trimmingCharacters(in: .whitespacesAndNewlines),
            notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        dismiss()
    }

    private func combinedDate() -> Date {
        let calendar = Calendar.current
        let day = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        let time = calendar.dateComponents([.hour, .minute], from: selectedTime)

        var components = DateComponents()
        components.year = day.year
        components.month = day.month
        components.day = day.day
        components.hour = time.hour
        components.minute = time.minute

        return calendar.date(from: components) ?? Date()
    }
}
